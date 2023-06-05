# Process html entity - &#123;, &#xAF;, &quot;, ...

import ..common.entities { entities }
import ..common.utils { isValidEntityCode }

var DIGITAL_RE = '/^&#((?:x[a-f0-9]{1,6}|[0-9]{1,7}));/i'
var NAMED_RE   = '/^&([a-z][a-z0-9]{1,31});/i'

def entity(state, silent) {
  var ch, code, match, token, pos = state.pos, max = state.posMax

  if state.src[pos] != '&' return false

  if pos + 1 >= max return false

  ch = state.src[pos + 1]

  if ch == '#' {
    match = state.src[pos,].match(DIGITAL_RE)
    if match {
      var match_markup = match[0]
      var match_length = match_markup.length()
      if !silent {
        code = match[1][0].lower() == 'x' ? to_number(match[1][1,]) : to_number(match[1])

        token         = state.push('text_special', '', 0)
        token.content = isValidEntityCode(code) ? chr(code) : chr(0xFFFD)
        token.markup  = match_markup
        token.info    = 'entity'
      }
      state.pos += match_length
      return true
    }
  } else {
    match = state.src[pos,].match(NAMED_RE)
    if match {
      if entities.contains(match[1]) {
        if !silent {
          token         = state.push('text_special', '', 0)
          token.content = entities[match[1]]
          token.markup  = match[0]
          token.info    = 'entity'
        }
        state.pos += match[0].length()
        return true
      }
    }
  }

  return false
}

