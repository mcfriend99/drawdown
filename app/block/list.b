# Lists

import ..common.utils { isSpace }

def _skipBulletListMarker(state, startLine) {
  var marker, pos, max, ch

  pos = state.bMarks[startLine] + state.tShift[startLine]
  max = state.eMarks[startLine]

  marker = state.src[pos++ - 1]
  # Check bullet
  if marker != '*' and marker != '-' and marker != '+' {
    return -1
  }

  if pos < max {
    ch = state.src[pos]

    if !isSpace(ch) {
      # " -test " - is not a list item
      return -1
    }
  }

  return pos
}

def _skipOrderedListMarker(state, startLine) {
  var ch,
      start = state.bMarks[startLine] + state.tShift[startLine],
      pos = start,
      max = state.eMarks[startLine]

  # List marker should have at least 2 chars (digit + dot)
  if pos + 1 >= max return -1

  ch = state.src[pos++ - 1]

  if ord(ch) < ord('0') or ord(ch) > ord('9') return -1

  iter ;; {
    # EOL -> fail
    if pos >= max return -1

    ch = state.src[pos++ - 1]

    if ord(ch) >= ord('0') and ord(ch) <= ord('9') {

      # List marker should have no more than 9 digits
      # (prevents integer overflow in browsers)
      if pos - start >= 10 return -1

      continue
    }

    # found valid marker
    if ch == ')' or ch == '.' {
      break
    }

    return -1
  }


  if pos < max {
    ch = state.src[pos]

    if !isSpace(ch) {
      # " 1.test " - is not a list item
      return -1
    }
  }
  return pos
}

def _markTightParagraphs(state, idx) {
  var i, l,
      level = state.level + 2

  i = idx + 2
  iter l = state.tokens.length() - 2; i < l; i++ {
    if state.tokens[i].level == level and state.tokens[i].type == 'paragraph_open' {
      state.tokens[i + 2].hidden = true
      state.tokens[i].hidden = true
      i += 2
    }
  }
}

def list(state, startLine, endLine, silent) {
  var ch,
      contentStart,
      i,
      indent,
      indentAfterMarker,
      initial,
      isOrdered,
      itemLines,
      l,
      listLines,
      listTokIdx,
      markerCharCode,
      markerValue,
      max,
      offset,
      oldListIndent,
      oldParentType,
      oldSCount,
      oldTShift,
      oldTight,
      pos,
      posAfterMarker,
      prevEmptyEnd,
      start,
      terminate,
      terminatorRules,
      token,
      nextLine = startLine,
      isTerminatingParagraph = false,
      tight = true

  # if it's indented more than 3 spaces, it should be a code block
  if state.sCount[nextLine] - state.blkIndent >= 4 return false

  # Special case:
  #  - item 1
  #   - item 2
  #    - item 3
  #     - item 4
  #      - this one is a paragraph continuation
  if state.listIndent >= 0 and
      state.sCount[nextLine] - state.listIndent >= 4 and
      state.sCount[nextLine] < state.blkIndent {
    return false
  }

  # limit conditions when list can interrupt
  # a paragraph (validation mode only)
  if silent and state.parentType == 'paragraph' {
    # Next list item should still terminate previous list item;
    #
    # This code can fail if plugins use blkIndent as well as lists,
    # but I hope the spec gets fixed long before that happens.
    #
    if state.sCount[nextLine] >= state.blkIndent {
      isTerminatingParagraph = true
    }
  }

  # Detect list type and position after marker
  if (posAfterMarker = _skipOrderedListMarker(state, nextLine)) >= 0 {
    isOrdered = true
    start = state.bMarks[nextLine] + state.tShift[nextLine]
    markerValue = to_number(state.src[start, posAfterMarker - 1])

    # If we're starting a new ordered list right after
    # a paragraph, it should start with 1.
    if isTerminatingParagraph and markerValue != 1 return false

  } else if (posAfterMarker = _skipBulletListMarker(state, nextLine)) >= 0 {
    isOrdered = false

  } else {
    return false
  }

  # If we're starting a new unordered list right after
  # a paragraph, first line should not be empty.
  if isTerminatingParagraph {
    if state.skipSpaces(posAfterMarker) >= state.eMarks[nextLine] return false
  }

  # For validation mode we can terminate immediately
  if silent return true

  # We should terminate list on style change. Remember first one to compare.
  markerCharCode = state.src[posAfterMarker - 1]

  # Start list
  listTokIdx = state.tokens.length()

  if isOrdered {
    token       = state.push('ordered_list_open', 'ol', 1)
    if markerValue != 1 {
      token.attrs = [ [ 'start', markerValue ] ]
    }

  } else {
    token       = state.push('bullet_list_open', 'ul', 1)
  }

  token.map    = listLines = [ nextLine, 0 ]
  token.markup = markerCharCode

  #
  # Iterate list items
  #

  prevEmptyEnd = false
  terminatorRules = state.md.block.ruler.getRules('list')

  oldParentType = state.parentType
  state.parentType = 'list'

  while nextLine < endLine {
    pos = posAfterMarker
    max = state.eMarks[nextLine]

    initial = offset = state.sCount[nextLine] + posAfterMarker - (state.bMarks[nextLine] + state.tShift[nextLine])

    while pos < max {
      ch = state.src[pos]

      if ch == '\t' {
        offset += 4 - (offset + state.bsCount[nextLine]) % 4
      } else if ch == ' ' {
        offset++
      } else {
        break
      }

      pos++
    }

    contentStart = pos

    if contentStart >= max {
      # trimming space in "-    \n  3" case, indent is 1 here
      indentAfterMarker = 1
    } else {
      indentAfterMarker = offset - initial
    }

    # If we have more than 4 spaces, the indent is 1
    # (the rest is just indented code block)
    if indentAfterMarker > 4 indentAfterMarker = 1

    # "  -  test"
    #  ^^^^^ - calculating total length of this thing
    indent = initial + indentAfterMarker

    # Run subparser & write tokens
    token        = state.push('list_item_open', 'li', 1)
    token.markup = markerCharCode
    token.map    = itemLines = [ nextLine, 0 ]
    if isOrdered {
      token.info = state.src[start, posAfterMarker - 1]
    }

    # change current state, then restore it after parser subcall
    oldTight = state.tight
    oldTShift = state.tShift[nextLine]
    oldSCount = state.sCount[nextLine]

    #  - example list
    # ^ listIndent position will be here
    #   ^ blkIndent position will be here
    #
    oldListIndent = state.listIndent
    state.listIndent = state.blkIndent
    state.blkIndent = indent

    state.tight = true
    state.tShift[nextLine] = contentStart - state.bMarks[nextLine]
    state.sCount[nextLine] = offset

    if contentStart >= max and state.isEmpty(nextLine + 1) {
      # workaround for this case
      # (list item is empty, list terminates before "foo"):
      # ~~~~~~~~
      #   -
      #
      #     foo
      # ~~~~~~~~
      state.line = min(state.line + 2, endLine)
    } else {
      state.md.block.tokenize(state, nextLine, endLine)
    }

    # If any of list item is tight, mark list as tight
    if !state.tight or prevEmptyEnd {
      tight = false
    }
    # Item become loose if finish with empty line,
    # but we should filter last element, because it means list finish
    prevEmptyEnd = (state.line - nextLine) > 1 and state.isEmpty(state.line - 1)

    state.blkIndent = state.listIndent
    state.listIndent = oldListIndent
    state.tShift[nextLine] = oldTShift
    state.sCount[nextLine] = oldSCount
    state.tight = oldTight

    token        = state.push('list_item_close', 'li', -1)
    token.markup = markerCharCode

    nextLine = state.line
    itemLines[1] = nextLine

    if nextLine >= endLine break

    #
    # Try to check if list is terminated or continued.
    #
    if state.sCount[nextLine] < state.blkIndent break

    # if it's indented more than 3 spaces, it should be a code block
    if state.sCount[nextLine] - state.blkIndent >= 4 break

    # fail if terminating block found
    terminate = false
    i = 0
    iter l = terminatorRules.length(); i < l; i++ {
      if terminatorRules[i](state, nextLine, endLine, true) {
        terminate = true
        break
      }
    }
    if terminate break

    # fail if list has another type
    if (isOrdered) {
      posAfterMarker = _skipOrderedListMarker(state, nextLine);
      if (posAfterMarker < 0) { break; }
      start = state.bMarks[nextLine] + state.tShift[nextLine];
    } else {
      posAfterMarker = _skipBulletListMarker(state, nextLine);
      if (posAfterMarker < 0) { break; }
    }

    if markerCharCode != state.src[posAfterMarker - 1] break
  }

  # Finalize list
  if isOrdered {
    token = state.push('ordered_list_close', 'ol', -1)
  } else {
    token = state.push('bullet_list_close', 'ul', -1)
  }
  token.markup = markerCharCode

  listLines[1] = nextLine
  state.line = nextLine

  state.parentType = oldParentType

  # mark paragraphs tight if needed
  if (tight) {
    _markTightParagraphs(state, listTokIdx)
  }

  return true
}

