# Parse backticks

def backticks(state, silent) {
  var start, max, marker, token, matchStart, matchEnd, openerLength, closerLength,
      pos = state.pos,
      ch = state.src[pos]

  if ch != '`' return false

  start = pos
  pos++
  max = state.posMax

  # scan marker length
  while pos < max and state.src[pos] == '`' pos++

  marker = state.src[start, pos]
  openerLength = marker.length()

  if state.backticksScanned and state.backticks.get(openerLength, 0) <= start {
    if !silent state.pending += marker
    state.pos += openerLength
    return true
  }

  matchEnd = pos

  # Nothing found in the cache, scan until the end of the line (or until marker is found)
  while (matchStart = state.src.index_of('`', matchEnd)) != -1 {
    matchEnd = matchStart + 1

    # scan marker length
    while matchEnd < max and state.src[matchEnd] == '`' matchEnd++

    closerLength = matchEnd - matchStart

    if closerLength == openerLength {
      # Found matching closer length.
      if !silent {
        token     = state.push('code_inline', 'code', 0)
        token.markup  = marker
        token.content = state.src[pos, matchStart].
          replace('/\n/', ' ').
          replace('/^ (.+) $/', '$1')
      }
      state.pos = matchEnd
      return true
    }

    # Some different length found, put it in cache as upper limit of where closer can be found
    state.backticks[closerLength] = matchStart
  }

  # Scanned through the end, didn't find anything
  state.backticksScanned = true

  if !silent state.pending += marker
  state.pos += openerLength
  return true
}

