import .ruler { Ruler }
import .core


var _rules = [
  [ 'normalize',      core.normalize     ],
  [ 'block',          core.block         ],
  [ 'inline',         core.inline        ],
  [ 'linkify',        core.linkify       ],
  [ 'replacements',   core.replacements  ],
  [ 'smartquotes',    core.smartquotes   ],
  # `text_join` finds `text_special` tokens (for escape sequences)
  # and joins them with the rest of the text
  [ 'text_join',      core.text_join     ]
]

/** 
 * internal
 * 
 * class Core
 *
 * Top-level rules executor. Glues block/inline parsers and does intermediate
 * transformations.
 */
class ParserCore {

  /**
   * Core#ruler
   *
   * [[Ruler]] instance. Keep configuration of core rules.
   * @type Ruler
   */
  var ruler = Ruler()

  ParserCore() {
    iter var i = 0; i < _rules.length(); i++ {
      self.ruler.push(_rules[i][0], _rules[i][1])
    }
  }

  /**
   * Core.process(state)
   *
   * Executes core chain rules.
   */
  process(state) {
    var i = 0, l, rules
  
    rules = self.ruler.getRules('')
  
    iter l = rules.length(); i < l; i++ {
      rules[i](state)
    }
  }

  var State = core.state_core.StateCore
}

