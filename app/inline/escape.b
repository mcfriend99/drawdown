# Process escaped chars and hardbreaks

import iters
import ..common.utils { isSpace }

# list mapping of escaped ASCII characters.
var ESCAPED = [0] * 256
iters.each('\\!"#$%&\'()*+,./:;<=>?@[]^_`{|}~-'.to_list(), @(ch) { ESCAPED[ord(ch)] = 1 })

def escape(state, silent) {
  var ch1, ch2, origStr, escapedStr, token, pos = state.pos, max = state.posMax

  if state.src[pos] != '\\' return false
  pos++

  # '\' at the end of the inline block
  if pos >= max return false

  ch1 = ord(state.src[pos])

  if ch1 == 0x0A {
    if !silent {
      state.push('hardbreak', 'br', 0)
    }

    pos++
    # skip leading whitespaces from next line
    while pos < max {
      ch1 = ord(state.src[pos])
      if !isSpace(ch1) break
      pos++
    }

    state.pos = pos
    return true
  }

  escapedStr = state.src[pos]

  if ch1 >= 0xD800 and ch1 <= 0xDBFF and pos + 1 < max {
    ch2 = ord(state.src[pos + 1])

    if ch2 >= 0xDC00 and ch2 <= 0xDFFF {
      escapedStr += state.src[pos + 1]
      pos++
    }
  }

  origStr = '\\' + escapedStr

  if !silent {
    token = state.push('text_special', '', 0)

    if ch1 < 256 and ESCAPED[ch1] != 0 {
      token.content = escapedStr
    } else {
      token.content = origStr
    }

    token.markup = origStr
    token.info   = 'escape'
  }

  state.pos = pos + 1
  return true
}

