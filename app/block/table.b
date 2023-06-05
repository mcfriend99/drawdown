# GFM table, https://github.github.com/gfm/#tables-extension-

import ..common.utils { isSpace }

def _getLine(state, line) {
  var pos = state.bMarks[line] + state.tShift[line],
      max = state.eMarks[line]

  return state.src[pos, max]
}

def _escapedSplit(str) {
  var result = [],
      pos = 0,
      max = str.length(),
      ch,
      isEscaped = false,
      lastPos = 0,
      current = ''

  ch  = str[pos]

  while pos < max {
    if ch == '|' {
      if !isEscaped {
        # pipe separating cells, '|'
        result.append(current + str[lastPos, pos])
        current = ''
        lastPos = pos + 1
      } else {
        # escaped pipe, '\|'
        current += str[lastPos, pos - 1]
        lastPos = pos
      }
    }
    
    isEscaped = ch == '\\'
    pos++

    if pos < max ch = str[pos]
  }

  result.append(current + (lastPos < str.length() ? str[lastPos,] : ''))

  return result
}

def table(state, startLine, endLine, silent) {
  var ch, lineText, pos, i, l, nextLine, columns, columnCount, token,
      aligns, t, tableLines, tbodyLines, oldParentType, terminate,
      terminatorRules, firstCh, secondCh

  # should have at least two lines
  if startLine + 2 > endLine return false

  nextLine = startLine + 1

  if state.sCount[nextLine] < state.blkIndent return false

  # if it's indented more than 3 spaces, it should be a code block
  if state.sCount[nextLine] - state.blkIndent >= 4 return false

  # first character of the second line should be '|', '-', ':',
  # and no other characters are allowed but spaces;
  # basically, this is the equivalent of /^[-:|][-:|\s]*$/ regexp

  pos = state.bMarks[nextLine] + state.tShift[nextLine]
  if pos >= state.eMarks[nextLine] return false

  firstCh = state.src[pos++ - 1]
  if firstCh != '|' and firstCh != '-' and firstCh != ':' return false

  if pos >= state.eMarks[nextLine] return false

  secondCh = state.src[pos++ - 1]
  if secondCh != '|' and secondCh != '-' and secondCh != ':' and !isSpace(secondCh) {
    return false
  }

  # if first character is '-', then second character must not be a space
  # (due to parsing ambiguity with list)
  if firstCh == '-' and isSpace(secondCh) return false

  while pos < state.eMarks[nextLine] {
    ch = state.src[pos]

    if ch != '|' and ch != '-' and ch != ':' and !isSpace(ch) return false

    pos++
  }

  lineText = _getLine(state, startLine + 1)

  columns = lineText.split('|')
  aligns = []
  iter i = 0; i < columns.length(); i++ {
    t = columns[i].trim()
    if !t {
      # allow empty columns before and after table, but not in between columns;
      # e.g. allow ` |---| `, disallow ` ---||--- `
      if i == 0 or i == columns.length() - 1 {
        continue
      } else {
        return false
      }
    }

    if !t.match('/^:?-+:?$/') return false
    if t[-1] == ':' {
      aligns.append(t[0] == ':' ? 'center' : 'right')
    } else if t[0] == ':' {
      aligns.append('left')
    } else {
      aligns.append('')
    }
  }

  lineText = _getLine(state, startLine).trim()
  if lineText.index_of('|') == -1 return false
  if state.sCount[startLine] - state.blkIndent >= 4 return false
  columns = _escapedSplit(lineText)
  if columns and columns[0] == '' columns.shift()
  if columns and columns[-1] == '' columns.pop()

  # header row will define an amount of columns in the entire table,
  # and align row should be exactly the same (the rest of the rows can differ)
  columnCount = columns.length()
  if columnCount == 0 or columnCount != aligns.length() return false

  if silent return true

  oldParentType = state.parentType
  state.parentType = 'table'

  # use 'blockquote' lists for termination because it's
  # the most similar to tables
  terminatorRules = state.md.block.ruler.getRules('blockquote')

  token     = state.push('table_open', 'table', 1)
  token.map = tableLines = [ startLine, 0 ]

  token     = state.push('thead_open', 'thead', 1)
  token.map = [ startLine, startLine + 1 ]

  token     = state.push('tr_open', 'tr', 1)
  token.map = [ startLine, startLine + 1 ]

  iter i = 0; i < columns.length(); i++ {
    token          = state.push('th_open', 'th', 1)
    if aligns[i] {
      token.attrs  = [ [ 'style', 'text-align:' + aligns[i] ] ]
    }

    token          = state.push('inline', '', 0)
    token.content  = columns[i].trim()
    token.children = []

    token          = state.push('th_close', 'th', -1)
  }

  token     = state.push('tr_close', 'tr', -1)
  token     = state.push('thead_close', 'thead', -1)

  iter nextLine = startLine + 2; nextLine < endLine; nextLine++ {
    if state.sCount[nextLine] < state.blkIndent break

    terminate = false
    i = 0
    iter l = terminatorRules.length(); i < l; i++ {
      if terminatorRules[i](state, nextLine, endLine, true) {
        terminate = true
        break
      }
    }

    if terminate break
    lineText = _getLine(state, nextLine).trim()
    if !lineText break
    if state.sCount[nextLine] - state.blkIndent >= 4 break
    columns = _escapedSplit(lineText)
    if columns and columns[0] == '' columns.shift()
    if columns and columns[-1] == '' columns.pop()

    if nextLine == startLine + 2 {
      token     = state.push('tbody_open', 'tbody', 1)
      token.map = tbodyLines = [ startLine + 2, 0 ]
    }

    token     = state.push('tr_open', 'tr', 1)
    token.map = [ nextLine, nextLine + 1 ]

    iter i = 0; i < columnCount; i++ {
      token          = state.push('td_open', 'td', 1)
      if aligns[i] {
        token.attrs  = [ [ 'style', 'text-align:' + aligns[i] ] ]
      }

      token          = state.push('inline', '', 0)
      token.content  = columns[i] ? columns[i].trim() : ''
      token.children = []

      token          = state.push('td_close', 'td', -1)
    }
    token = state.push('tr_close', 'tr', -1)
  }

  if tbodyLines {
    token = state.push('tbody_close', 'tbody', -1)
    tbodyLines[1] = nextLine
  }

  token = state.push('table_close', 'table', -1)
  tableLines[1] = nextLine

  state.parentType = oldParentType
  state.line = nextLine
  return true
}

