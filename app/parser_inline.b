import .ruler { Ruler }
import .inline

# Parser rules

var _rules = [
  [ 'text',            inline.text ],
  [ 'linkify',         inline.linkify ],
  [ 'newline',         inline.newline ],
  [ 'escape',          inline.escape ],
  [ 'backticks',       inline.backticks ],
  [ 'strikethrough',   inline.strikethrough.tokenize ],
  [ 'emphasis',        inline.emphasis.tokenize ],
  [ 'link',            inline.link ],
  [ 'image',           inline.image ],
  [ 'autolink',        inline.autolink ],
  [ 'html_inline',     inline.html_inline ],
  [ 'entity',          inline.entity ]
]

# `rule2` ruleset was created specifically for emphasis/strikethrough
# post-processing and may be changed in the future.
#
# Don't use this for anything except pairs (plugins working with `balance_pairs`).
var _rules2 = [
  [ 'balance_pairs',   inline.balance_pairs ],
  [ 'strikethrough',   inline.strikethrough.postProcess ],
  [ 'emphasis',        inline.emphasis.postProcess ],
  # rules for pairs separate '**' into its own text tokens, which may be left unused,
  # rule below merges unused segments back with the rest of the text
  [ 'fragments_join',  inline.fragments_join ]
]


/** 
 * internal
 * 
 * class ParserInline
 *
 * Tokenizes paragraph content.
 */
class ParserInline {

  /**
   * ParserInline#ruler
   *
   * [[Ruler]] instance. Keep configuration of core rules.
   * @type Ruler
   */
  var ruler = Ruler()

  /**
   * ParserInline#ruler2
   * 
   *[[Ruler]] instance. Second ruler used for post-processing
   * (e.g. in emphasis-like rules).
   * @type Ruler
   */
  var ruler2 = Ruler()

  ParserInline() {
    iter var i = 0; i < _rules.length(); i++ {
      self.ruler.push(_rules[i][0], _rules[i][1])
    }
  
    iter var i = 0; i < _rules2.length(); i++ {
      self.ruler2.push(_rules2[i][0], _rules2[i][1])
    }
  }

  /**
   * Skip single token by running all rules in validation mode
   */
  skipToken(state) {
    var ok, i, pos = state.pos,
        rules = self.ruler.getRules(''),
        len = rules.length(),
        maxNesting = state.md.options.maxNesting,
        cache = state.cache

    if cache.contains(pos) {
      state.pos = cache[pos]
      return
    }
  
    if state.level < maxNesting {
      iter i = 0; i < len; i++ {
        # Increment state.level and decrement it later to limit recursion.
        # It's harmless to do here, because no tokens are created. But ideally,
        # we'd need a separate private state variable for this purpose.
        state.level++
        ok = rules[i](state, true)
        state.level--
  
        if ok {
          if pos >= state.pos die Exception("inline rule didn't increment state position")
          break
        }
      }
    } else {
      # Too much nesting, just skip until the end of the paragraph.
      #
      # NOTE: this will cause links to behave incorrectly in the following case,
      #       when an amount of `[` is exactly equal to `maxNesting + 1`:
      #
      #       [[[[[[[[[[[[[[[[[[[[[foo]()
      #
      # TODO: remove this workaround when CM standard will allow nested links
      #       (we can replace it by preventing links from being parsed in
      #       validation mode)
      state.pos = state.posMax
    }
    
    if !ok state.pos++
    cache[pos] = state.pos
  }

  /**
   * Generate tokens for input range
   */
  tokenize(state) {
    var ok, i,
        rules = self.ruler.getRules(''),
        len = rules.length(),
        end = state.posMax,
        maxNesting = state.md.options.maxNesting
  
    while state.pos < end {
      # Try all possible rules.
      # On success, rule should:
      #
      # - update `state.pos`
      # - update `state.tokens`
      # - return true
  
      var prevPos = state.pos
      if state.level < maxNesting {
        iter i = 0; i < len; i++ {
          ok = rules[i](state, false)
          if ok {
            if prevPos >= state.pos die Exception("inline rule didn't increment state.pos")
            break
          }
        }
      }

      if ok {
        if state.pos >= end break
        continue
      }
  
      state.pending += state.src[state.pos++ - 1]
    }
  
    if state.pending {
      state.pushPending()
    }
  }

  /**
   * ParserInline.parse(str, md, env, outTokens)
   *
   * Process input string and push inline tokens into `outTokens`
   */
  parse(str, md, env, outTokens) {
    var i, rules, len
    var state = self.State(str, md, env, outTokens)
  
    self.tokenize(state)
  
    rules = self.ruler2.getRules('')
    len = rules.length()
  
    iter i = 0; i < len; i++ {
      rules[i](state)
    }
  }

  var State = inline.state_inline.StateInline
}

