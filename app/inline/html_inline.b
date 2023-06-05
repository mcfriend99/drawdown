# Process HTML tags

import ..common.html_re { HTML_TAG_RE }

def _isLinkOpen(str) {
  return str.match('/^<a[>\s]/i')
}

def _isLinkClose(str) {
  return str.match('/^<\/a\s*>/i')
}

def _isLetter(ch) {
  var lc = ch | 0x20 # to lower case
  return (lc >= 0x61/* a */) and (lc <= 0x7a/* z */)
}

def html_inline(state, silent) {
  var ch, match, max, token,
      pos = state.pos

  if !state.md.options.html return false

  # Check start
  max = state.posMax
  if state.src[pos] != '<' or pos + 2 >= max {
    return false
  }

  # Quick fail on second char
  ch = state.src[pos + 1]
  if ch != '!' and ch != '?' and ch != '/' and !_isLetter(ord(ch)) {
    return false
  }

  match = state.src[pos,].match(HTML_TAG_RE)
  if !match return false

  if !silent {
    token         = state.push('html_inline', '', 0)
    token.content = match[0]

    if _isLinkOpen(token.content)  state.linkLevel++
    if _isLinkClose(token.content) state.linkLevel--
  }
  state.pos += match[0].length()
  return true
}

