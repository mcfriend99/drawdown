import .common.utils { assign, unescapeAll, escapeHtml }

var default_rules = {}

default_rules.code_inline = @(tokens, idx, options, env, slf) {
  var token = tokens[idx]

  return  '<code' + slf.renderAttrs(token) + '>' +
          escapeHtml(token.content) +
          '</code>'
}

default_rules.code_block = @(tokens, idx, options, env, slf) {
  var token = tokens[idx]

  return  '<pre' + slf.renderAttrs(token) + '><code>' +
          escapeHtml(token.content) +
          '</code></pre>\n'
}

default_rules.fence = @(tokens, idx, options, env, slf) {
  var token = tokens[idx],
      info = token.info ? unescapeAll(token.info).trim() : '',
      langName = '',
      langAttrs = '',
      highlighted, i, arr, tmpAttrs, tmpToken

  if info {
    arr = info.split('/(\s+)/')
    langName = arr[0]
    langAttrs = ''.join(arr[2,])
  }

  if options.highlight {
    highlighted = options.highlight(token.content, langName, langAttrs) or escapeHtml(token.content)
  } else {
    highlighted = escapeHtml(token.content)
  }

  if highlighted.index_of('<pre') == 0 {
    return highlighted + '\n'
  }

  # If language exists, inject class gently, without modifying original token.
  # May be, one day we will add .deepClone() for token and simplify this part, but
  # now we prefer to keep things local.
  if info {
    i        = token.attrIndex('class')
    tmpAttrs = token.attrs ? token.attrs[,] : []

    if i < 0 {
      tmpAttrs.append([ 'class', options.langPrefix + langName ])
    } else {
      tmpAttrs[i] = tmpAttrs[i][,]
      tmpAttrs[i][1] += ' ' + options.langPrefix + langName
    }

    # Fake token just to render attributes
    tmpToken = {
      attrs: tmpAttrs
    }

    return  '<pre><code' + slf.renderAttrs(tmpToken) + '>' +
            highlighted +
            '</code></pre>\n'
  }

  return  '<pre><code' + slf.renderAttrs(token) + '>' +
          highlighted +
          '</code></pre>\n'
}

default_rules.image = @(tokens, idx, options, env, slf) {
  var token = tokens[idx]

  # "alt" attr MUST be set, even if empty. Because it's mandatory and
  # should be placed on proper position for tests.
  #
  # Replace content with actual value

  token.attrs[token.attrIndex('alt')][1] =
    slf.renderInlineAsText(token.children, options, env)

  return slf.renderToken(tokens, idx, options)
}

default_rules.hardbreak = @(tokens, idx, options , env, slf) {
  return options.xhtmlOut ? '<br />\n' : '<br>\n'
}
default_rules.softbreak = @(tokens, idx, options , env, slf) {
  return options.breaks ? (options.xhtmlOut ? '<br />\n' : '<br>\n') : '\n'
}

default_rules.text = @(tokens, idx , options, env, slf) {
  return escapeHtml(tokens[idx].content)
}


default_rules.html_block = @(tokens, idx , options, env, slf) {
  return tokens[idx].content
}
default_rules.html_inline = @(tokens, idx , options, env, slf) {
  return tokens[idx].content
}

/**
 * class Renderer
 *
 * Generates HTML from parsed token stream. Each instance has independent
 * copy of rules. Those can be rewritten with ease. Also, you can add new
 * rules if you create plugin and adds new token types.
 */
class Renderer {

  /**
   * Renderer#rules -> Dictionary
   *
   * Contains render rules for tokens. Can be updated and extended.
   *
   * ##### Example
   *
   * ```blade
   * import markdown as md
   *
   * md.renderer.rules.strong_open  = @() { return '<b>' }
   * md.renderer.rules.strong_close = @() { return '</b>' }
   *
   * var result = md.renderInline(...)
   * ```
   *
   * Each rule is called as independent static function with fixed signature:
   *
   * ```blade
   * function my_token_render(tokens, idx, options, env, renderer) {
   *   # ...
   *   return renderedHTML
   * }
   * ```
   */
  var rules = assign({}, default_rules)

  /**
   * Renderer.renderAttrs(token) -> String
   *
   * Render token attributes to string.
   */
  renderAttrs(token) {
    var i = 0, l, result
  
    if !token.attrs return ''
  
    result = ''
  
    iter l = token.attrs.length(); i < l; i++ {
      result += ' ' + escapeHtml(to_string(token.attrs[i][0])) + '="' + escapeHtml(to_string(token.attrs[i][1])) + '"'
    }
  
    return result
  }

  /**
   * Renderer.renderToken(tokens, idx, options)
   *
   * Default token renderer. Can be overriden by custom function
   * in [[Renderer#rules]].
   * 
   * @param {list} tokens: list of tokens
   * @param {number} idx: token index to render
   * @param {dict} options: params of parser instance
   * @return string
   */
  renderToken(tokens, idx, options) {
    var nextToken,
        result = '',
        needLf = false,
        token = tokens[idx]
  
    # Tight list paragraphs
    if token.hidden {
      return ''
    }
  
    # Insert a newline between hidden paragraph and subsequent opening
    # block-level tag.
    #
    # For example, here we should insert a newline before blockquote:
    #  - a
    #    >
    if token.block and token.nesting != -1 and idx and tokens[idx - 1].hidden {
      result += '\n'
    }
  
    # Add token name, e.g. `<img`
    result += (token.nesting == -1 ? '</' : '<') + token.tag
  
    # Encode attributes, e.g. `<img src="foo"`
    result += self.renderAttrs(token)
  
    # Add a slash for self-closing tags, e.g. `<img src="foo" /`
    if token.nesting == 0 and options.xhtmlOut {
      result += ' /'
    }
  
    # Check if we need to add a newline after this tag
    if token.block {
      needLf = true
  
      if token.nesting == 1 {
        if idx + 1 < tokens.length() {
          nextToken = tokens[idx + 1]
  
          if nextToken.type == 'inline' or nextToken.hidden {
            # Block-level tag containing an inline tag.
            #
            needLf = false
  
          } else if nextToken.nesting == -1 and nextToken.tag == token.tag {
            # Opening tag + closing tag of the same type. E.g. `<li></li>`.
            #
            needLf = false
          }
        }
      }
    }
  
    result += needLf ? '>\n' : '>'
  
    return result
  }

  /**
   * Renderer.renderInline(tokens, options, env)
   *
   * The same as [[Renderer.render]], but for single token of `inline` type.
   * 
   * @param {list} tokens: list on block tokens to render
   * @param {dict} options: params of parser instance
   * @param {dict} env: additional data from parsed input (references, for example)
   * @return string
   */
  renderInline(tokens, options, env) {
    var type,
        result = '',
        rules = self.rules,
        i = 0
  
    iter var len = tokens.length(); i < len; i++ {
      type = tokens[i].type
  
      if rules.contains(type) {
        result += rules[type](tokens, i, options, env, self)
      } else {
        result += self.renderToken(tokens, i, options)
      }
    }
  
    return result
  }

  /** internal
   * 
   * Renderer.renderInlineAsText(tokens, options, env)
   *
   * Special kludge for image `alt` attributes to conform CommonMark spec.
   * Don't try to use it! Spec requires to show `alt` content with stripped markup,
   * instead of simple escaping.
   * 
   * @param {list} tokens: list on block tokens to render
   * @param {dict} options: params of parser instance
   * @param {dict} env: additional data from parsed input (references, for example)
   * @return string
   */
  renderInlineAsText(tokens, options, env) {
    var result = '', i = 0
  
    iter var len = tokens.length(); i < len; i++ {
      if tokens[i].type == 'text' {
        result += tokens[i].content
      } else if tokens[i].type == 'image' {
        result += self.renderInlineAsText(tokens[i].children, options, env)
      } else if tokens[i].type == 'softbreak' {
        result += '\n'
      }
    }
  
    return result
  }

  /**
   * Renderer.render(tokens, options, env)
   *
   * Takes token stream and generates HTML. Probably, you will never need to call
   * this method directly.
   * 
   * @param {list} tokens: list on block tokens to render
   * @param {dict} options: params of parser instance
   * @param {dict} env: additional data from parsed input (references, for example)
   * @return string
   **/
  render(tokens, options, env) {
    var i = 0, len, type,
        result = '',
        rules = self.rules
  
    iter len = tokens.length(); i < len; i++ {
      type = tokens[i].type
  
      if type == 'inline' {
        result += self.renderInline(tokens[i].children, options, env)
      } else if rules.contains(type) {
        result += rules[type](tokens, i, options, env, self)
      } else {
        result += self.renderToken(tokens, i, options)
      }
    }
  
    return result
  }
}

