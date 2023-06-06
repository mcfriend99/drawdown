import .common.utils
import .helpers
import .renderer { Renderer }
import .parser_core { Parser_core }
import .parser_block { Parser_block }
import .parser_inline { Parser_inline }
import .config as presets
import url
import iters
import reflect
import convert { decimal_to_hex }

var _working_rules = [ 'core', 'block', 'inline' ]

var config = {
  zero: presets.zero,
  standard: presets.standard,
  commonmark: presets.commonmark,
}

########################################
#
# This validator can prohibit more than really needed to prevent XSS. It's a
# tradeoff to keep code simple and to be secure by default.
#
# If you need different setup - override validator method as you wish. Or
# replace it with dummy def and use external sanitizer.
#

var BAD_PROTO_RE = '/^(vbscript|javascript|file|data):/'
var GOOD_DATA_RE = '/^data:image\/(gif|png|jpeg|webp);/'

def validate_link(url) {
  # url should be normalized at this point, and existing entities are decoded
  var str = url.trim().lower()

  return str.match(BAD_PROTO_RE) ? (str.match(GOOD_DATA_RE) ? true : false) : true
}

########################################


var RECODE_HOSTNAME_FOR = [ 'http:', 'https:', 'mailto:' ]

def _md_format(url) {
  var result = ''
  result += url.scheme ? '${url.scheme}:' : ''
  if !url.has_slash {
    if !url.scheme and url.host and !url.username {
      result += url.port or !url.path ? '' : '/'
    }
  } else {
    result += '//'
  }
  result += url.username ? url.username : ''
  result += url.password ? ':${url.password}' : ''
  result += url.username ? '@' : ''
  if url.host and url.host.index_of(':') != -1 {
    # ipv6 address
    result += '[' + url.host + ']'
  } else {
    result += url.host ? url.host.ltrim('/') : ''
  }
  
  result += url.port and url.port != '0' ? ':' + url.port : ''
  result += !url.path or url.path == '/' ? '' : url.path
  result += url.query ? '?${url.query}' : ''
  result += url.hash ? '#${url.hash}' : ''
  return result
}

var encode_cache = {}
def _get_encode_cache(exclude) {
  var i, ch, cache = encode_cache.get(exclude)
  if cache  return cache

  cache = encode_cache[exclude] = []

  iter i = 0; i < 128; i++ {
    ch = chr(i)
    if ch.match('/^[0-9a-z]$/i') {
      #  always allow unencoded alphanumeric characters
      cache.append(ch)
    } else {
      var cache_code = ('0' + decimal_to_hex(i).upper())
      cache.append('%' + cache_code[cache_code.length() - 2,])
    }
  }
  iter i = 0; i < exclude.length(); i++ {
    cache[ord(exclude[i])] = exclude[i]
  }
  return cache
}

/**
 * encode_url(string, exclude, keep_escaped)
 * 
 * Encode unsafe characters with percent-encoding, skipping already
 * encoded sequences.
 * 
 * @param {string} string: string to encode
 * @param {list|string} exclude: list of characters to ignore (in addition to a-zA-Z0-9)
 * @param {bool} keep_escaped: don't encode '%' in a correct escape sequence (default: true)
 * @return string
 */
def encode_url(string, exclude, keep_escaped) {
  var i = 0, l, code, nextCode, cache, result = ''
  if !is_string(exclude) {
    # encode(string, keep_escaped)
    keep_escaped = exclude
    exclude = ';/?:@&=+$,-_.!~*\'()#'
  }
  if keep_escaped == nil keep_escaped = true
  
  cache = _get_encode_cache(exclude)
  
  iter l = string.length(); i < l; i++ {
    code = ord(string[i])
    if keep_escaped and code == '%' and i + 2 < l {
      if string[i + 1, i + 3].match('/^[0-9a-f]{2}$/i') {
        result += string[i, i + 3]
        i += 2
        continue
      }
    }
    if code < 128 {
      result += cache[code]
      continue
    }
    if code >= 55296 and code <= 57343 {
      if code >= 55296 and code <= 56319 and i + 1 < l {
        nextCode = ord(string[i + 1])
        if nextCode >= 56320 and nextCode <= 57343 {
          result += url.encode(string[i] + string[i + 1])
          i++
          continue
        }
      }
      result += "%EF%BF%BD"
      continue
    }
    result += url.encode(string[i])
  }
  
  return result
}

def normalize_link(uri) {
  var parsed = url.parse(uri)

  if parsed.host {
    # Encode hostnames in urls like:
    # `http://host/`, `https://host/`, `mailto:user@host`, `//host/`
    #
    # We don't encode unknown schemas, because it's likely that we encode
    # something we shouldn't (e.g. `skype:name` treated as `skype:host`)
    if !parsed.scheme or RECODE_HOSTNAME_FOR.contains(parsed.scheme) >= 0 {
      parsed.host.ascii()
    }
  }

  # return encode_url(parsed.absolute_url())
  return encode_url(_md_format(parsed))
}

def normalize_link_text(uri) {
  var parsed = url.parse(uri)

  if parsed.host {
    # Encode hostnames in urls like:
    # `http:#host/`, `https:#host/`, `mailto:user@host`, `#host/`
    #
    # We don't encode unknown schemas, because it's likely that we encode
    # something we shouldn't (e.g. `skype:name` treated as `skype:host`)
    if !parsed.scheme or RECODE_HOSTNAME_FOR.contains(parsed.scheme) >= 0 {
      parsed.host.ascii(false)
    }
  }

  # return parsed.absolute_url()
  return _md_format(parsed)
}


/**
 * class Markdown
 *
 * Main parser/renderer class.
 *
 * ##### Usage
 *
 * ```javascript
 * # node.js, "classic" way:
 * var Markdown = require('markdown'),
 *     md = Markdown()
 * var result = md.render('# markdown rulezz!')
 *
 * # node.js, the same, but with sugar:
 * var md = require('markdown')()
 * var result = md.render('# markdown rulezz!')
 *
 * # browser without AMD, added to "window" on script load
 * # Note, there are no dash.
 * var md = window.markdownit()
 * var result = md.render('# markdown rulezz!')
 * ```
 *
 * Single line rendering, without paragraph wrap:
 *
 * ```javascript
 * var md = require('markdown')()
 * var result = md.render_inline('__markdown__ rulezz!')
 * ```
 */
class Markdown {

  /**
   * Markdown#inline -> Parser_inline
   *
   * Instance of [[Parser_inline]]. You may need it to add new rules when
   * writing plugins. For simple rules control use [[Markdown.disable]] and
   * [[Markdown.enable]].
   */
  var inline = Parser_inline()

  /**
   * Markdown#block -> Parser_block
   *
   * Instance of [[Parser_block]]. You may need it to add new rules when
   * writing plugins. For simple rules control use [[Markdown.disable]] and
   * [[Markdown.enable]].
   */
  var block = Parser_block()

  /**
   * Markdown#core -> Core
   *
   * Instance of [[Core]] chain executor. You may need it to add new rules when
   * writing plugins. For simple rules control use [[Markdown.disable]] and
   * [[Markdown.enable]].
   */
  var core = Parser_core()

  /**
   * Markdown#renderer -> Renderer
   *
   * Instance of [[Renderer]]. Use it to modify output look. Or to add rendering
   * rules for new token types, generated by plugins.
   *
   * ##### Example
   *
   * ```javascript
   * var md = require('markdown')()
   *
   * def my_token(tokens, idx, options, env, self) {
   *   #...
   *   return result
   * }
   *
   * md.renderer.rules['my_token'] = my_token
   * ```
   *
   * See [[Renderer]] docs and [source code](https:#github.com/markdown/markdown/blob/master/lib/renderer.js).
   */
  var renderer = Renderer()

  /**
   * Markdown#validate_link(url) -> bool
   *
   * Link validation function. Common_mark allows too much in links. By default
   * we disable `javascript:`, `vbscript:`, `file:` schemas, and almost all `data:...` schemas
   * except some embedded image types.
   *
   * You can change this behaviour:
   *
   * ```javascript
   * var md = require('markdown')()
   * # enable everything
   * md.validate_link = def () { return true; }
   * ```
   */
  var validate_link = validate_link

  /**
   * Markdown#normalize_link(url) -> string
   *
   * def used to encode link url to a machine-readable format,
   * which includes url-encoding, punycode, etc.
   */
  var normalize_link = normalize_link

  /**
   * Markdown#normalize_link_text(url) -> String
   *
   * def used to decode link url to a human-readable format`
   */
  var normalize_link_text = normalize_link_text


  # Expose utils & helpers for easy acces from plugins

  /**
   * Markdown#utils -> utils
   *
   * Assorted utility functions, useful to write plugins. See details
   * [here](https:#github.com/markdown/markdown/blob/master/lib/common/utils.js).
   */
  var utils = utils

  /**
   * Markdown#helpers -> helpers
   *
   * Link components parser functions, useful to write plugins. See details
   * [here](https:#github.com/markdown/markdown/blob/master/lib/helpers).
   */
  var helpers = {
    parse_link_destination: helpers.parse_link_destination,
    parse_link_label: helpers.parse_link_label,
    parse_link_title: helpers.parse_link_title,
  }

  /**
   * Markdown([preset_name, options])
   * - preset_name (String): optional, `commonmark` / `zero`
   * - options (Object)
   *
   * Creates parser instanse with given config. Can be called without `new`.
   *
   * ##### preset_name
   *
   * Markdown provides named presets as a convenience to quickly
   * enable/disable active syntax rules and options for common use cases.
   *
   * - ["commonmark"](https:#github.com/markdown/markdown/blob/master/lib/presets/commonmark.js) -
   *   configures parser to strict [Common_mark](http:#commonmark.org/) mode.
   * - [default](https:#github.com/markdown/markdown/blob/master/lib/presets/default.js) -
   *   similar to GFM, used when no preset name given. Enables all available rules,
   *   but still without html, typographer & autolinker.
   * - ["zero"](https:#github.com/markdown/markdown/blob/master/lib/presets/zero.js) -
   *   all rules disabled. Useful to quickly setup your config via `.enable()`.
   *   For example, when you need only `bold` and `italic` markup and nothing else.
   *
   * ##### options:
   *
   * - __html__ - `false`. Set `true` to enable HTML tags in source. Be careful!
   *   That's not safe! You may need external sanitizer to protect output from XSS.
   *   It's better to extend features via plugins, instead of enabling HTML.
   * - __xhtml_out__ - `false`. Set `true` to add '/' when closing single tags
   *   (`<br />`). This is needed only for full Common_mark compatibility. In real
   *   world you will need HTML output.
   * - __breaks__ - `false`. Set `true` to convert `\n` in paragraphs into `<br>`.
   * - __lang_prefix__ - `language-`. CSS language class prefix for fenced blocks.
   *   Can be useful for external highlighters.
   * - __linkify__ - `false`. Set `true` to autoconvert URL-like text to links.
   * - __typographer__  - `false`. Set `true` to enable [some language-neutral
   *   replacement](https:#github.com/markdown/markdown/blob/master/lib/rules_core/replacements.js) +
   *   quotes beautification (smartquotes).
   * - __quotes__ - `“”‘’`, String or Array. Double + single quotes replacement
   *   pairs, when typographer enabled and smartquotes on. For example, you can
   *   use `'«»„“'` for Russian, `'„“‚‘'` for German, and
   *   `['«\xA0', '\xA0»', '‹\xA0', '\xA0›']` for French (including nbsp).
   * - __highlight__ - `null`. Highlighter def for fenced code blocks.
   *   Highlighter `def (str, lang)` should return escaped HTML. It can also
   *   return empty string if the source was not changed and should be escaped
   *   externaly. If result starts with <pre... internal wrapper is skipped.
   *
   * ##### Example
   *
   * ```javascript
   * # commonmark mode
   * var md = require('markdown')('commonmark')
   *
   * # default mode
   * var md = require('markdown')()
   *
   * # enable everything
   * var md = require('markdown')({
   *   html: true,
   *   linkify: true,
   *   typographer: true
   * })
   * ```
   *
   * ##### Syntax highlighting
   *
   * ```js
   * var hljs = require('highlight.js') # https:#highlightjs.org/
   *
   * var md = require('markdown')({
   *   highlight: def (str, lang) {
   *     if (lang and hljs.get_language(lang)) {
   *       try {
   *         return hljs.highlight(str, { language: lang, ignore_illegals: true }).value
   *       } catch (__) {}
   *     }
   *
   *     return ''; # use external default escaping
   *   }
   * })
   * ```
   *
   * Or with full wrapper override (if you need assign class to `<pre>`):
   *
   * ```javascript
   * var hljs = require('highlight.js') # https:#highlightjs.org/
   *
   * # Actual default values
   * var md = require('markdown')({
   *   highlight: def (str, lang) {
   *     if (lang and hljs.get_language(lang)) {
   *       try {
   *         return '<pre class="hljs"><code>' +
   *                hljs.highlight(str, { language: lang, ignore_illegals: true }).value +
   *                '</code></pre>'
   *       } catch (__) {}
   *     }
   *
   *     return '<pre class="hljs"><code>' + md.utils.escape_html(str) + '</code></pre>'
   *   }
   * })
   * ```
   *
   */
  Markdown(preset_name, options) {
    if !instance_of(self, Markdown) {
      Markdown(preset_name, options)
    } else {
      if !options {
        if !is_string(preset_name) {
          options = preset_name or {}
          preset_name = 'standard'
        }
      }
  
  
      self.options = {}
      self.configure(preset_name)
  
      if options self.set(options)
    }
  }

  /**
   * Markdown.set(options)
   *
   * Set parser options (in the same format as in constructor). Probably, you
   * will never need it, but you can change options after constructor call.
   *
   * ##### Example
   *
   * ```javascript
   * var md = require('markdown')()
   *             .set({ html: true, breaks: true })
   *             .set({ typographer, true })
   * ```
   *
   * __Note:__ To achieve the best possible performance, don't modify a
   * `markdown` instance options on the fly. If you need multiple configurations
   * it's best to create multiple instances and initialize each with separate
   * config.
   * 
   * @chainable
   */
  set(options) {
    utils.assign(self.options, options)
    return self
  }

  /**
   * Markdown.configure(presets)
   *
   * Batch load of all options and compenent settings. This is internal method,
   * and you probably will not need it. But if you will - see available presets
   * and data structure [here](https:#github.com/markdown/markdown/tree/master/lib/presets)
   *
   * We strongly recommend to use presets instead of direct config loads. That
   * will give better compatibility with next versions.
   * 
   * @chainable
   * @internal
   */
  configure(presets) {
    var preset_name

    if is_string(presets) {
      preset_name = presets
      presets = config[preset_name]
      if !presets die Exception('Wrong `markdown` preset "' + preset_name + '", check name')
    }

    if !presets die Exception('Wrong `markdown` preset, can\'t be empty')

    if presets.options self.set(presets.options)

    if presets.components {
      iters.each(presets.components.keys(), @(name) {
        if presets.components[name].get('rules') {
          reflect.get_prop(self, name).ruler.enable_only(presets.components[name].rules)
        }
        if presets.components[name].get('rules2') {
          reflect.get_prop(self, name).ruler2.enable_only(presets.components[name].rules2)
        }
      })
    }

    return self
  }

  /**
   * Markdown.enable(list, ignore_invalid)
   * 
   * - list (String|Array): rule name or list of rule names to enable
   * - ignore_invalid (Boolean): set `true` to ignore errors when rule not found.
   *
   * Enable list or rules. It will automatically find appropriate components,
   * containing rules with given names. If rule not found, and `ignore_invalid`
   * not set - throws exception.
   *
   * ##### Example
   *
   * ```javascript
   * var md = require('markdown')()
   *             .enable(['sub', 'sup'])
   *             .disable('smartquotes')
   * ```
   * 
   * @chainable
   */
  enable(list, ignore_invalid) {
    var result = []

    if !is_list(list) list = [ list ]

    iters.each(_working_rules, @(chain) {
      result += reflect.get_props(self, chain).ruler.enable(list, true)
    })

    result += self.inline.ruler2.enable(list, true)

    var missed = iters.filter(list, @(name) { return result.index_of(name) < 0 })

    if missed.length() and !ignore_invalid {
      die Exception('Markdown. Failed to enable unknown rule(s): ' + missed)
    }

    return self
  }

  /**
   * Markdown.disable(list, ignore_invalid)
   * 
   * - list (String|Array): rule name or list of rule names to disable.
   * - ignore_invalid (Boolean): set `true` to ignore errors when rule not found.
   *
   * The same as [[Markdown.enable]], but turn specified rules off.
   * 
   * @chainable
   */
  disable(list, ignore_invalid) {
    var result = []

    if !is_list(list) list = [ list ]

    iters.each(_working_rules, @(chain) {
      result += reflect.get_prop(self, chain).ruler.disable(list, true)
    })

    result += self.inline.ruler2.disable(list, true)

    var missed = iters.filter(list, @(name) { return result.index_of(name) < 0 })

    if missed.length() and !ignore_invalid {
      die Exception('Markdown. Failed to disable unknown rule(s): ' + missed)
    }

    return self
  }

  /**
   * Markdown.use(plugin, params)
   *
   * Load specified plugin with given params into current parser instance.
   * It's just a sugar to call `plugin(md, params)` with curring.
   *
   * ##### Example
   *
   * ```javascript
   * var iterator = require('markdown-for-inline')
   * var md = require('markdown')()
   *             .use(iterator, 'foo_replace', 'text', def (tokens, idx) {
   *               tokens[idx].content = tokens[idx].content.replace(/foo/g, 'bar')
   *             })
   * ```
   * 
   * @chainable
   */
  use(plugin, ...) {
    plugin(self, __args__)
    return self
  }

  /**
   * Markdown.parse(src, env) -> Array
   * - src (String): source string
   * - env (Object): environment sandbox
   *
   * Parse input string and return list of block tokens (special token type
   * "inline" will contain list of inline tokens). You should not call this
   * method directly, until you write custom renderer (for example, to produce
   * AST).
   *
   * `env` is used to pass data between "distributed" rules and return additional
   * metadata like reference info, needed for the renderer. It also can be used to
   * inject data in specific cases. Usually, you will be ok to pass `{}`,
   * and then pass updated object to renderer.
   * 
   * @internal
   */
  parse(src, env) {
    if !is_string(src) {
      die Exception('Input data should be a String')
    }

    var state = self.core.State(src, self, env)

    self.core.process(state)

    return state.tokens
  }

  /**
   * Markdown.render(src [, env]) -> String
   * - src (String): source string
   * - env (Object): environment sandbox
   *
   * Render markdown string into html. It does all magic for you :).
   *
   * `env` can be used to inject additional metadata (`{}` by default).
   * But you will not need it with high probability. See also comment
   * in [[Markdown.parse]].
   */
  render(src, env) {
    env = env or {}

    return self.renderer.render(self.parse(src, env), self.options, env)
  }

  /**
   * Markdown.parse_inline(src, env) -> Array
   * - src (String): source string
   * - env (Object): environment sandbox
   *
   * The same as [[Markdown.parse]] but skip all block rules. It returns the
   * block tokens list with the single `inline` element, containing parsed inline
   * tokens in `children` property. Also updates `env` object.
   * 
   * @internal
   **/
  parse_inline(src, env) {
    var state = self.core.State(src, self, env)

    state.inline_mode = true
    self.core.process(state)

    return state.tokens
  }

  /**
   * Markdown.render_inline(src [, env]) -> String
   * - src (String): source string
   * - env (Object): environment sandbox
   *
   * Similar to [[Markdown.render]] but for single paragraph content. Result
   * will NOT be wrapped into `<p>` tags.
   */
  render_inline(src, env) {
    env = env or {}

    return self.renderer.render(self.parse_inline(src, env), self.options, env)
  }
}

