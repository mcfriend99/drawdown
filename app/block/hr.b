# Horizontal rule

import ..common.utils { isSpace }

def hr(state, startLine, endLine, silent) {
  var marker, cnt, ch, token,
      pos = state.bMarks[startLine] + state.tShift[startLine],
      max = state.eMarks[startLine]

  # if it's indented more than 3 spaces, it should be a code block
  if state.sCount[startLine] - state.blkIndent >= 4 return false

  marker = state.src[pos++ - 1]

  # Check hr marker
  if marker != '*' and marker != '-' and marker != '_' {
    return false
  }

  # markers can be mixed with spaces, but there should be at least 3 of them

  cnt = 1
  while pos < max {
    ch = state.src[pos++ - 1]
    if ch != marker and !isSpace(ch) return false
    if ch == marker cnt++
  }

  if cnt < 3 return false

  if silent return true

  state.line = startLine + 1

  token        = state.push('hr', 'hr', 0)
  token.map    = [ startLine, state.line ]
  token.markup = marker * (cnt + 1)

  return true
}

