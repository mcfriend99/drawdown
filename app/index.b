import convert { hex_to_decimal }

def getDefaults() {
  return {
    async: false,
    baseUrl: nil,
    breaks: false,
    extensions: nil,
    gfm: true,
    headerIds: true,
    headerPrefix: '',
    highlight: nil,
    hooks: nil,
    langPrefix: 'language-',
    mangle: true,
    pedantic: false,
    renderer: nil,
    sanitize: false,
    sanitizer: nil,
    silent: false,
    smartypants: false,
    tokenizer: nil,
    walkTokens: nil,
    xhtml: false,
  }
}

var defaults = getDefaults()

def changeDefaults(newDefaults) {
  defaults = newDefaults
}

/**
 * Helpers
 */
var escapeTest = '/[&<>"\']/'
var escapeReplace = '/${escapeTest}/s'
var escapeTestNoEncode = '/[<>"\']|&(?!(#\d{1,7}|#[Xx][a-fA-F0-9]{1,6}|\w+);)/'
var escapeReplaceNoEncode = '/${escapeTestNoEncode}/s'
var escapeReplacements = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
}
var getEscapeReplacement = @(ch) { return escapeReplacements[ch] }
def escape(html, encode) {
  if encode {
    if html.match(escapeTest) {
      return html.replace(escapeReplace, getEscapeReplacement)
    }
  } else {
    if html.match(escapeTestNoEncode) {
      return html.replace(escapeReplaceNoEncode, getEscapeReplacement)
    }
  }

  return html
}

var unescapeTest = '/&(#(?:\d+)|(?:#x[0-9A-Fa-f]+)|(?:\w+));?/i'

/**
 * @param {string} html
 */
def unescape(html) {
  # explicitly match decimal, hex, and named HTML entities
  return html.replace(unescapeTest, @(_, n) {
    n = n.lower()
    if n == 'colon' return ':'
    if n[0] == '#' {
      return n[1] == 'x' ? 
        chr(hex_to_decimal(n[2,])) : 
        chr(to_number(n[1,]))
    }
    return ''
  })
}



