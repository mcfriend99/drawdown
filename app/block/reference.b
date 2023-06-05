import ..common.utils { isSpace }
import ..common.utils { normalizeReference }

def reference(state, startLine, _endLine, silent) {
  var ch,
      destEndPos,
      destEndLineNo,
      endLine,
      href,
      i,
      l,
      label,
      labelEnd = -1,
      oldParentType,
      res,
      start,
      str,
      terminate,
      terminatorRules,
      title,
      lines = 0,
      pos = state.bMarks[startLine] + state.tShift[startLine],
      max = state.eMarks[startLine],
      nextLine = startLine + 1

  # if it's indented more than 3 spaces, it should be a code block
  if state.sCount[startLine] - state.blkIndent >= 4 return false

  if state.src[pos] != '[' return false

  # Simple check to quickly interrupt scan on [link](url) at the start of line.
  # Can be useful on practice: https:#github.com/markdown-it/markdown-it/issues/54
  while pos++ < max {
    if state.src[pos] == ']' and state.src[pos - 1] != '\\' {
      if pos + 1 == max return false
      if state.src[pos + 1] != ':' return false
      break
    }
  }

  endLine = state.lineMax

  # jump line-by-line until empty one or EOF
  terminatorRules = state.md.block.ruler.getRules('reference')

  oldParentType = state.parentType
  state.parentType = 'reference'

  iter ; nextLine < endLine and !state.isEmpty(nextLine); nextLine++ {
    # this would be a code block normally, but after paragraph
    # it's considered a lazy continuation regardless of what's there
    if state.sCount[nextLine] - state.blkIndent > 3 continue

    # quirk for blockquotes, this line should already be checked by that rule
    if state.sCount[nextLine] < 0 continue

    # Some tags can terminate paragraph without empty line.
    terminate = false
    i = 0
    iter l = terminatorRules.length(); i < l; i++ {
      if terminatorRules[i](state, nextLine, endLine, true) {
        terminate = true
        break
      }
    }
    if terminate break
  }

  str = state.getLines(startLine, nextLine, state.blkIndent, false).trim()
  max = str.length()

  iter pos = 1; pos < max; pos++ {
    ch = str[pos]
    if ch == '[' {
      return false
    } else if ch == ']' {
      labelEnd = pos
      break
    } else if ch == '\n' {
      lines++
    } else if ch == '\\' {
      pos++
      if pos < max and str[pos] == '\n' {
        lines++
      }
    }
  }

  if labelEnd < 0 or str.length() <= labelEnd + 1 or str[labelEnd + 1] != ':' return false

  # [label]:   destination   'title'
  #         ^^^ skip optional whitespace here
  iter pos = labelEnd + 2; pos < max; pos++ {
    ch = str[pos]
    if ch == '\n' {
      lines++
    } else if isSpace(ch) {
    } else {
      break
    }
  }

  # [label]:   destination   'title'
  #            ^^^^^^^^^^^ parse this
  res = state.md.helpers.parseLinkDestination(str, pos, max)
  if !res.ok return false


  href = state.md.normalizeLink(res.str)
  if !state.md.validateLink(href) return false

  pos = res.pos
  lines += res.lines

  # save cursor state, we could require to rollback later
  destEndPos = pos
  destEndLineNo = lines

  # [label]:   destination   'title'
  #                       ^^^ skipping those spaces
  start = pos
  iter ; pos < max; pos++ {
    ch = str[pos]
    if ch == '\n' {
      lines++
    } else if isSpace(ch) {
    } else {
      break
    }
  }

  # [label]:   destination   'title'
  #                          ^^^^^^^ parse this
  res = state.md.helpers.parseLinkTitle(str, pos, max)
  if pos < max and start != pos and res.ok {
    title = res.str
    pos = res.pos
    lines += res.lines
  } else {
    title = ''
    pos = destEndPos
    lines = destEndLineNo
  }

  # skip trailing spaces until the rest of the line
  while pos < max {
    ch = str[pos]
    if !isSpace(ch) break
    pos++
  }

  if pos < max and str[pos] != '\n' {
    if title {
      # garbage at the end of the line after title,
      # but it could still be a valid reference if we roll back
      title = ''
      pos = destEndPos
      lines = destEndLineNo
      while pos < max {
        ch = str[pos]
        if !isSpace(ch) break
        pos++
      }
    }
  }

  if pos < max and str[pos] != '\n' {
    # garbage at the end of the line
    return false
  }

  label = normalizeReference(str[1, labelEnd])
  if !label {
    # CommonMark 0.20 disallows empty labels
    return false
  }

  # Reference can not terminate anything. This check is for safety only.
  /*istanbul ignore if*/
  if silent return true

  if !state.env.contains('references') {
    state.env.references = {}
  }
  if !state.env.references.contains('label') {
    state.env.references[label] = { title: title, href: href }
  }

  state.parentType = oldParentType

  state.line = startLine + lines + 1
  return true
}

