# HTML block

import ..common.html_blocks { html_blocks }
import ..common.html_re { HTML_OPEN_CLOSE_TAG_RE }

# A list of opening and corresponding closing sequences for html tags,
# last argument defines whether it can terminate a paragraph or not
var HTML_SEQUENCES = [
  [ '/^<(script|pre|style|textarea)(?=(\s|>|$))/i', '/<\/(script|pre|style|textarea)>/i', true ],
  [ '/^<!--/',        '/-->/',   true ],
  [ '/^<\?/',         '/\?>/',   true ],
  [ '/^<![A-Z]/',     '/>/',     true ],
  [ '/^<!\[CDATA\[/', '/\]\]>/', true ],
  [ '/^</?(' + '|'.join(html_blocks) + ')(?=(\\s|/?>|$))/i', '/^$/', true ],
  [ '/${HTML_OPEN_CLOSE_TAG_RE}\\s*$/',  '/^$/', false ],
]

def html_block(state, startLine, endLine, silent) {
  var i, nextLine, token, lineText,
      pos = state.bMarks[startLine] + state.tShift[startLine],
      max = state.eMarks[startLine]

  # if it's indented more than 3 spaces, it should be a code block
  if state.sCount[startLine] - state.blkIndent >= 4 return false

  if !state.md.options.html return false

  if state.src[pos] != '<' return false

  lineText = state.src[pos, max]

  iter i = 0; i < HTML_SEQUENCES.length(); i++ {
    if lineText.match(HTML_SEQUENCES[i][0]) break
  }

  if i == HTML_SEQUENCES.length() return false

  if silent {
    # true if this sequence can be a terminator, false otherwise
    return HTML_SEQUENCES[i][2]
  }

  nextLine = startLine + 1

  # If we are here - we detected HTML block.
  # Let's roll down till block end.
  if !lineText.match(HTML_SEQUENCES[i][1]) {
    iter ; nextLine < endLine; nextLine++ {
      if state.sCount[nextLine] < state.blkIndent break

      pos = state.bMarks[nextLine] + state.tShift[nextLine]
      max = state.eMarks[nextLine]
      lineText = state.src[pos, max]

      if lineText.match(HTML_SEQUENCES[i][1]) {
        if lineText.length() != 0 nextLine++
        break
      }
    }
  }

  state.line = nextLine

  token         = state.push('html_block', '', 0)
  token.map     = [ startLine, nextLine ]
  token.content = state.getLines(startLine, nextLine, state.blkIndent, true)

  return true
}

