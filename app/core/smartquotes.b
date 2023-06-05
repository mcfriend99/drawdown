# Convert straight quotation marks to typographic ones

import ..common.utils { isWhiteSpace, isPunctChar, isMdAsciiPunct }

var QUOTE_RE = '/[\'"]/'
var APOSTROPHE = '\u2019' /* ’ */

def _replaceAt(str, index, ch) {
  return str[,index] + ch + str[index + 1,]
}

def _process_inlines(tokens, state) {
  var i, token, text, t, pos, max, thisLevel, item, lastChar, nextChar,
      isLastPunctChar, isNextPunctChar, isLastWhiteSpace, isNextWhiteSpace,
      canOpen, canClose, j, isSingle, stack, openQuote, closeQuote;

  stack = []

  iter i = 0; i < tokens.length(); i++ {
    token = tokens[i]

    thisLevel = tokens[i].level

    iter j = stack.length() - 1; j >= 0; j-- {
      if stack[j].level <= thisLevel break
    }
    while stack.length() > j + 1 stack.pop()
    # stack.length = j + 1

    if token.type != 'text' continue

    text = token.content
    pos = 0
    max = text.length()

    while pos < max {
      t = text[pos,].match(QUOTE_RE)
      if !t break

      var t_index = text.index_of(t[0], pos)
      t = t[0]

      canOpen = canClose = true
      pos = t_index + 1
      isSingle = t[0] == "'"

      # Find previous character,
      # default to space if it's the beginning of the line
      lastChar = ' '

      if t_index - 1 >= 0 {
        lastChar = text[t_index - 1]
      } else {
        iter j = i - 1; j >= 0; j-- {
          if tokens[j].type == 'softbreak' or tokens[j].type == 'hardbreak' break # lastChar defaults to 0x20
          if !tokens[j].content continue # should skip all tokens except 'text', 'html_inline' or 'code_inline'

          lastChar = tokens[j].content[tokens[j].content.length() - 1]
          break
        }
      }

      # Find next character,
      # default to space if it's the end of the line
      nextChar = ' '

      if pos < max {
        nextChar = text[pos]
      } else {
        iter j = i + 1; j < tokens.length(); j++ {
          if tokens[j].type == 'softbreak' or tokens[j].type == 'hardbreak' break # nextChar defaults to 0x20
          if !tokens[j].content continue # should skip all tokens except 'text', 'html_inline' or 'code_inline'

          nextChar = tokens[j].content[0]
          break
        }
      }

      isLastPunctChar = isMdAsciiPunct(lastChar) or isPunctChar(lastChar)
      isNextPunctChar = isMdAsciiPunct(nextChar) or isPunctChar(nextChar)

      isLastWhiteSpace = isWhiteSpace(lastChar)
      isNextWhiteSpace = isWhiteSpace(nextChar)

      if isNextWhiteSpace {
        canOpen = false
      } else if isNextPunctChar {
        if !(isLastWhiteSpace or isLastPunctChar) {
          canOpen = false
        }
      }

      if isLastWhiteSpace {
        canClose = false
      } else if isLastPunctChar {
        if !(isNextWhiteSpace or isNextPunctChar) {
          canClose = false
        }
      }

      if nextChar == '"' and t[0] == '"' {
        if ord(lastChar) >= 0x30 /* 0 */ and ord(lastChar) <= 0x39 /* 9 */ {
          # special case: 1"" - count first quote as an inch
          canClose = canOpen = false
        }
      }

      if canOpen and canClose {
        # Replace quotes in the middle of punctuation sequence, but not
        # in the middle of the words, i.e.:
        #
        # 1. foo " bar " baz - not replaced
        # 2. foo-"-bar-"-baz - replaced
        # 3. foo"bar"baz     - not replaced
        canOpen = isLastPunctChar
        canClose = isNextPunctChar
      }

      if !canOpen and !canClose {
        # middle of word
        if isSingle {
          token.content = _replaceAt(token.content, t_index, APOSTROPHE)
        }
        continue
      }

      if canClose {
        # this could be a closing quote, rewind the stack to get a match
        var continue_outer = false
        iter j = stack.length() - 1; j >= 0; j-- {
          item = stack[j]
          if stack[j].level < thisLevel break
          if item.single == isSingle and stack[j].level == thisLevel {
            item = stack[j]

            if isSingle {
              openQuote = state.md.options.quotes[2]
              closeQuote = state.md.options.quotes[3]
            } else {
              openQuote = state.md.options.quotes[0]
              closeQuote = state.md.options.quotes[1]
            }

            # replace token.content *before* tokens[item.token].content,
            # because, if they are pointing at the same token, replaceAt
            # could mess up indices when quote length != 1
            token.content = _replaceAt(token.content, t_index, closeQuote)
            tokens[item.token].content = _replaceAt(
              tokens[item.token].content, item.pos, openQuote)

            pos += closeQuote.length() - 1
            if item.token == i pos += openQuote.length() - 1

            text = token.content
            max = text.length()

            while stack.length() > j stack.pop()
            # stack.length = j

            continue_outer = true
            break
          }
        }

        if continue_outer continue
      }

      if canOpen {
        stack.append({
          token: i,
          pos: t_index,
          single: isSingle,
          level: thisLevel,
        })
      } else if canClose and isSingle {
        token.content = _replaceAt(token.content, t_index, APOSTROPHE)
      }
    }
  }
}

def smartquotes(state) {
  if !state.md.options.typographer return

  iter var blkIdx = state.tokens.length() - 1; blkIdx >= 0; blkIdx-- {

    if state.tokens[blkIdx].type != 'inline' or
        !state.tokens[blkIdx].content.match(QUOTE_RE) {
      continue
    }

    _process_inlines(state.tokens[blkIdx].children, state)
  }
}

