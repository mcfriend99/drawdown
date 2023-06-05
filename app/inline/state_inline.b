# Inline parser state

import ..token as _tkn
import ..common.utils { isWhiteSpace, isPunctChar, isMdAsciiPunct }

class StateInline {
  
  /**
   * Stores { start: end } pairs. Useful for backtrack
   * optimization of pairs parse (emphasis, strikes).
   * @type dict
   */
  var cache = {}

  /**
   * List of emphasis-like delimiters for current tag
   * @type list
   */
  var delimiters = []

  # Stack of delimiter lists for upper level tags
  var _prev_delimiters = []

  # backtick length => last seen position
  var backticks = {}
  var backticksScanned = false

  /**
   * Counter used to disable inline linkify execution
   * inside <a> and markdown links
   * @type number
   */
  var linkLevel = 0

  var level = 0
  var pending = ''
  var pendingLevel = 0
  var pos = 0

  StateInline(src, md, env, outTokens) {
    self.src = src
    self.env = env
    self.md = md
    self.tokens = outTokens
    self.tokens_meta = [nil] * outTokens.length()
    self.posMax = self.src.length()
  }

  /**
   * Flush pending text
   */
  pushPending() {
    var token = _tkn.Token('text', '', 0)
    token.content = self.pending
    token.level = self.pendingLevel
    self.tokens.append(token)
    self.pending = ''
    return token
  }

  /**
   * Push new token to "stream".
   * If pending text exists - flush it as text token
   */
  push(type, tag, nesting) {
    if self.pending {
      self.pushPending()
    }
  
    var token = _tkn.Token(type, tag, nesting)
    var token_meta = nil
  
    if nesting < 0 {
      # closing tag
      self.level--
      self.delimiters = self._prev_delimiters.pop()
    }
  
    token.level = self.level
  
    if nesting > 0 {
      # opening tag
      self.level++
      self._prev_delimiters.append(self.delimiters)
      self.delimiters = []
      token_meta = { delimiters: self.delimiters }
    }
  
    self.pendingLevel = self.level
    self.tokens.append(token)
    self.tokens_meta.append(token_meta)
    return token
  }

  /**
   * Scan a sequence of emphasis-like markers, and determine whether
   * it can start an emphasis sequence or end an emphasis sequence.
   * 
   *   - start - position to scan from (it should point at a valid marker)
   *   - canSplitWord - determine if these markers can be found inside a word
   */
  scanDelims(start, canSplitWord) {
    var pos = start, lastChar, nextChar, count, can_open, can_close,
        isLastWhiteSpace, isLastPunctChar,
        isNextWhiteSpace, isNextPunctChar,
        left_flanking = true,
        right_flanking = true,
        max = self.posMax,
        marker = self.src[start]
  
    # treat beginning of the line as a whitespace
    lastChar = start > 0 ? self.src[start - 1] : ' '
  
    while pos < max and self.src[pos] == marker pos++
  
    count = pos - start
  
    # treat end of the line as a whitespace
    nextChar = pos < max ? self.src[pos] : ' '
  
    isLastPunctChar = isMdAsciiPunct(lastChar) or isPunctChar(lastChar)
    isNextPunctChar = isMdAsciiPunct(nextChar) or isPunctChar(nextChar)
  
    isLastWhiteSpace = isWhiteSpace(lastChar)
    isNextWhiteSpace = isWhiteSpace(nextChar)
  
    if isNextWhiteSpace {
      left_flanking = false
    } else if isNextPunctChar {
      if !(isLastWhiteSpace or isLastPunctChar) {
        left_flanking = false
      }
    }
  
    if isLastWhiteSpace {
      right_flanking = false
    } else if isLastPunctChar {
      if !(isNextWhiteSpace or isNextPunctChar) {
        right_flanking = false
      }
    }
  
    if !canSplitWord {
      can_open  = left_flanking  and (!right_flanking or isLastPunctChar)
      can_close = right_flanking and (!left_flanking  or isNextPunctChar)
    } else {
      can_open  = left_flanking
      can_close = right_flanking
    }
  
    return {
      can_open:  can_open,
      can_close: can_close,
      length:    count
    }
  }

  var Token = _tkn.Token
}

