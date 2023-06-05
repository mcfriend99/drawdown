# heading (#, ##, ...)

import ..common.utils { isSpace }

def heading(state, startLine, endLine, silent) {
  var ch, level, tmp, token,
      pos = state.bMarks[startLine] + state.tShift[startLine],
      max = state.eMarks[startLine]

  # if it's indented more than 3 spaces, it should be a code block
  if state.sCount[startLine] - state.blkIndent >= 4 return false

  ch  = state.src[pos]

  if ch != '#' or pos >= max return false

  # count heading level
  level = 1
  ch = state.src[pos++]
  while ch == '#' and pos < max and level <= 6 {
    level++
    ch = state.src[pos++]
  }

  if level > 6 or (pos < max and !isSpace(ch)) return false

  if silent return true

  # Let's cut tails like '    ###  ' from the end of string

  max = state.skipSpacesBack(max, pos)
  tmp = state.skipCharsBack(max, '#', pos) # #
  if tmp > pos and isSpace(state.src[tmp - 1]) {
    max = tmp
  }

  state.line = startLine + 1

  token        = state.push('heading_open', 'h' + level, 1)
  token.markup = '########'[,level]
  token.map    = [ startLine, state.line ]

  token          = state.push('inline', '', 0)
  token.content  = state.src[pos, max].trim()
  token.map      = [ startLine, state.line ]
  token.children = []

  token        = state.push('heading_close', 'h' + level, -1)
  token.markup = '########'[,level]

  return true
}

