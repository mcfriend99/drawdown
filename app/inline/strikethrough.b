# ~~strike through~~

# Insert each marker as a separate text token, and add it to delimiter list
def tokenize(state, silent) {
  var i, scanned, token, len, ch,
      start = state.pos,
      marker = state.src[start]

  if silent return false

  if marker != '~' return false

  scanned = state.scanDelims(state.pos, true)
  len = scanned.length
  ch = marker

  if len < 2 return false

  if len % 2 {
    token         = state.push('text', '', 0)
    token.content = ch
    len--
  }

  iter i = 0; i < len; i += 2 {
    token         = state.push('text', '', 0)
    token.content = ch + ch

    state.delimiters.append({
      marker: marker,
      length: 0,     # disable "rule of 3" length checks meant for emphasis
      token:  state.tokens.length() - 1,
      end:    -1,
      open:   scanned.can_open,
      close:  scanned.can_close
    })
  }

  state.pos += scanned.length

  return true
}

def _postProcess(state, delimiters) {
  var i, j,
      startDelim,
      endDelim,
      token,
      loneMarkers = [],
      max = delimiters.length()
      
  iter i = 0; i < max; i++ {
    startDelim = delimiters[i]

    if startDelim.marker != '~' {
      continue
    }

    if startDelim.end == -1 {
      continue
    }

    endDelim = delimiters[startDelim.end]

    token         = state.tokens[startDelim.token]
    token.type    = 's_open'
    token.tag     = 's'
    token.nesting = 1
    token.markup  = '~~'
    token.content = ''

    token         = state.tokens[endDelim.token]
    token.type    = 's_close'
    token.tag     = 's'
    token.nesting = -1
    token.markup  = '~~'
    token.content = ''

    if state.tokens[endDelim.token - 1].type == 'text' and
        state.tokens[endDelim.token - 1].content == '~' {

      loneMarkers.append(endDelim.token - 1)
    }
  }

  # If a marker sequence has an odd number of characters, it's splitted
  # like this: `~~~~~` -> `~` + `~~` + `~~`, leaving one marker at the
  # start of the sequence.
  #
  # So, we have to move all those markers after subsequent s_close tags.
  #
  while loneMarkers.length() > 0 {
    i = loneMarkers.pop()
    j = i + 1

    while j < state.tokens.length() and state.tokens[j].type == 's_close' {
      j++
    }

    j--

    if i != j {
      token = state.tokens[j]
      state.tokens[j] = state.tokens[i]
      state.tokens[i] = token
    }
  }
}


# Walk through delimiter list and replace text tokens with tags
def postProcess(state) {
  var curr,
      tokens_meta = state.tokens_meta,
      max = state.tokens_meta.length()

  _postProcess(state, state.delimiters)

  iter curr = 0; curr < max; curr++ {
    if tokens_meta[curr] and tokens_meta[curr].delimiters {
      _postProcess(state, tokens_meta[curr].delimiters)
    }
  }
}

