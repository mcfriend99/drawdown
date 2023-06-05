# Replace link-like texts with link nodes.

import ..common.utils { arrayReplaceAt }
import ..common.html_re { LINKS_RE }
import url as _url

def _isLinkOpen(str) {
  return str.match('/^<a[>\s]/i')
}
def _isLinkClose(str) {
  return str.match('/^<\/a\s*>/i')
}

def linkify(state) {
  var i, j = 0, l, tokens, token, currentToken, nodes, ln, text, pos, lastPos,
      level, htmlLinkLevel, url, fullUrl, urlText,
      blockTokens = state.tokens,
      links

  if !state.md.options.linkify return

  iter l = blockTokens.length(); j < l; j++ {
    if blockTokens[j].type != 'inline' or !blockTokens[j].content.match(LINKS_RE) {
      continue
    }

    tokens = blockTokens[j].children

    htmlLinkLevel = 0

    # We scan from the end, to keep position when new tags added.
    # Use reversed logic in links start/end match
    iter i = tokens.length() - 1; i >= 0; i-- {
      currentToken = tokens[i]

      # Skip content of markdown links
      if currentToken.type == 'link_close' {
        i--
        while tokens[i].level != currentToken.level and tokens[i].type != 'link_open' {
          i--
        }
        continue
      }

      # Skip content of html tag links
      if currentToken.type == 'html_inline' {
        if _isLinkOpen(currentToken.content) and htmlLinkLevel > 0 {
          htmlLinkLevel--
        }
        if _isLinkClose(currentToken.content) {
          htmlLinkLevel++
        }
      }
      if htmlLinkLevel > 0 continue

      if currentToken.type == 'text' and currentToken.content.match(LINKS_RE) {

        text = currentToken.content

        var links_matched = text.matches(LINKS_RE)
        if links_matched {
          links = []
          for link in links_matched[0] {
            links.append(_url.parse(link))
          }
        }

        # Now split string to nodes
        nodes = []
        level = currentToken.level
        lastPos = 0

        # forbid escape sequence at the start of the string,
        # this avoids http\://example.com/ from being linkified as
        # http:<a href="//example.com/">//example.com/</a>
        if links.length() > 0 and links[0].index == 0 and i > 0 and 
          tokens[i - 1].type == 'text_special' {
          links = links[1,]
        }

        iter ln = 0; ln < links.length(); ln++ {
          url = links[ln].url
          fullUrl = state.md.normalizeLink(url)
          if !state.md.validateLink(fullUrl) continue

          urlText = links[ln].to_string()

          # Linkifier might send raw hostnames like "example.com", where url
          # starts with domain name. So we prepend http:# in those cases,
          # and remove it afterwards.
          if !links[ln].schema {
            urlText = state.md.normalizeLinkText('http://' + urlText).replace('/^http:\/\//', '')
          } else if links[ln].schema == 'mailto' and !urlText.match('/^mailto:/i') {
            urlText = state.md.normalizeLinkText('mailto:' + urlText).replace('/^mailto:/', '')
          } else {
            urlText = state.md.normalizeLinkText(urlText)
          }

          pos = links[ln].index

          if pos > lastPos {
            token         = state.Token('text', '', 0)
            token.content = text[lastPos, pos]
            token.level   = level
            nodes.append(token)
          }

          token         = state.Token('link_open', 'a', 1)
          token.attrs   = [ [ 'href', fullUrl ] ]
          token.level   = level++
          token.markup  = 'linkify'
          token.info    = 'auto'
          nodes.append(token)

          token         = state.Token('text', '', 0)
          token.content = urlText
          token.level   = level
          nodes.append(token)

          token         = state.Token('link_close', 'a', -1)
          token.level   = level--
          token.markup  = 'linkify'
          token.info    = 'auto'
          nodes.append(token)

          lastPos = links[ln].lastIndex;
        }
        if lastPos < text.length() {
          token         = state.Token('text', '', 0)
          token.content = text[lastPos,]
          token.level   = level
          nodes.append(token)
        }

        # replace current node
        blockTokens[j].children = tokens = arrayReplaceAt(tokens, i, nodes)
      }
    }
  }
}

