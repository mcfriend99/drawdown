# Process [link](<to> "stuff")

import ..common.utils { normalizeReference, isSpace }

def link(state, silent) {
  var attrs,
      code,
      label,
      labelEnd,
      labelStart,
      pos,
      res,
      ref,
      token,
      href = '',
      title = '',
      oldPos = state.pos,
      max = state.posMax,
      start = state.pos,
      parseReference = true

  if state.src[state.pos] != '[' return false

  labelStart = state.pos + 1
  labelEnd = state.md.helpers.parseLinkLabel(state, state.pos, true)

  # parser failed to find ']', so it's not a valid link
  if labelEnd < 0 return false

  pos = labelEnd + 1
  if pos < max and state.src[pos] == '(' {
    #
    # Inline link
    #

    # might have found a valid shortcut link, disable reference parsing
    parseReference = false

    # [link](  <href>  "title"  )
    #        ^^ skipping these spaces
    pos++
    iter ; pos < max; pos++ {
      code = state.src[pos]
      if !isSpace(code) and code != '\n' break
    }
    if pos >= max return false

    # [link](  <href>  "title"  )
    #          ^^^^^^ parsing link destination
    start = pos
    res = state.md.helpers.parseLinkDestination(state.src, pos, state.posMax)
    if res.ok {
      href = state.md.normalizeLink(res.str)
      if state.md.validateLink(href) {
        pos = res.pos
      } else {
        href = ''
      }

      # [link](  <href>  "title"  )
      #                ^^ skipping these spaces
      start = pos
      iter ; pos < max; pos++ {
        code = state.src[pos]
        if !isSpace(code) and code != '\n' break
      }

      # [link](  <href>  "title"  )
      #                  ^^^^^^^ parsing link title
      res = state.md.helpers.parseLinkTitle(state.src, pos, state.posMax)
      if pos < max and start != pos and res.ok {
        title = res.str
        pos = res.pos

        # [link](  <href>  "title"  )
        #                         ^^ skipping these spaces
        iter ; pos < max; pos++ {
          code = state.src[pos]
          if !isSpace(code) and code != '\n' break
        }
      }
    }

    if pos >= max or state.src[pos] != ')' {
      # parsing a valid shortcut link failed, fallback to reference
      parseReference = true
    }
    pos++
  }

  if parseReference {
    #
    # Link reference
    #
    if !state.env.contains('references') return false

    if pos < max and state.src[pos] == '[' {
      start = pos + 1
      pos = state.md.helpers.parseLinkLabel(state, pos)
      if pos >= 0 {
        label = state.src[start, pos++ - 1]
      } else {
        pos = labelEnd + 1
      }
    } else {
      pos = labelEnd + 1
    }

    # covers label == '' and label == undefined
    # (collapsed reference link and shortcut reference link respectively)
    if !label label = state.src[labelStart, labelEnd]

    ref = state.env.references.get(normalizeReference(label), nil)
    if !ref {
      state.pos = oldPos
      return false
    }
    href = ref.href
    title = ref.title
  }

  #
  # We found the end of the link, and know for a fact it's a valid link
  # so all that's left to do is to call tokenizer.
  #
  if !silent {
    state.pos = labelStart
    state.posMax = labelEnd

    token        = state.push('link_open', 'a', 1)
    token.attrs  = attrs = [ [ 'href', href ] ]
    if title {
      attrs.append([ 'title', title ])
    }

    state.linkLevel++
    state.md.inline.tokenize(state)
    state.linkLevel--

    token        = state.push('link_close', 'a', -1)
  }

  state.pos = pos
  state.posMax = max
  return true
}

