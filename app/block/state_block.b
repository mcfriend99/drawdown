# Parser state class

import ..common.utils { isSpace }
import ..token as _tkn

class StateBlock {
  StateBlock(src, md, env, tokens) {
    var ch, s, start, pos, len, indent, offset, indent_found
  
    self.src = src
  
    # link to parser instance
    self.md     = md
  
    self.env = env
  
    #
    # Internal state vartiables
    #
  
    self.tokens = tokens
  
    self.bMarks = []  # line begin offsets for fast jumps
    self.eMarks = []  # line end offsets for fast jumps
    self.tShift = []  # offsets of the first non-space characters (tabs not expanded)
    self.sCount = []  # indents for each line (tabs expanded)
  
    # An amount of virtual spaces (tabs expanded) between beginning
    # of each line (bMarks) and real beginning of that line.
    #
    # It exists only as a hack because blockquotes override bMarks
    # losing information in the process.
    #
    # It's used only when expanding tabs, you can think about it as
    # an initial tab length, e.g. bsCount=21 applied to string `\t123`
    # means first tab should be expanded to 4-21%4 == 3 spaces.
    #
    self.bsCount = []
  
    # block parser variables
    self.blkIndent  = 0 # required block content indent (for example, if we are
                         # inside a list, it would be positioned after list marker)
    self.line       = 0 # line index in src
    self.lineMax    = 0 # lines count
    self.tight      = false  # loose/tight mode for lists
    self.ddIndent   = -1 # indent of the current dd block (-1 if there isn't any)
    self.listIndent = -1 # indent of the current list block (-1 if there isn't any)
  
    # can be 'blockquote', 'list', 'root', 'paragraph' or 'reference'
    # used in lists to determine if they interrupt a paragraph
    self.parentType = 'root'
  
    self.level = 0
  
    # renderer
    self.result = ''
  
    # Create caches
    # Generate markers.
    s = self.src
    indent_found = false
  
    start = pos = indent = offset = 0
    iter len = s.length(); pos < len; pos++ {
      ch = s[pos]
  
      if !indent_found {
        if isSpace(ch) {
          indent++
  
          if ch == '\t' {
            offset += 4 - offset % 4
          } else {
            offset++
          }
          continue
        } else {
          indent_found = true
        }
      }
  
      if ch == '\n' or pos == len - 1 {
        if ch != '\n' pos++
        self.bMarks.append(start)
        self.eMarks.append(pos)
        self.tShift.append(indent)
        self.sCount.append(offset)
        self.bsCount.append(0)
  
        indent_found = false
        indent = 0
        offset = 0
        start = pos + 1
      }
    }
  
    # Push fake entry to simplify cache bounds checks
    self.bMarks.append(s.length())
    self.eMarks.append(s.length())
    self.tShift.append(0)
    self.sCount.append(0)
    self.bsCount.append(0)
  
    self.lineMax = self.bMarks.length() - 1 # don't count last fake line
  }

  push(type, tag, nesting) {
    var tkn = _tkn.Token(type, tag, nesting)
    tkn.block = true
  
    if nesting < 0 self.level-- # closing tag
    tkn.level = self.level
    if nesting > 0 self.level++ # opening tag
  
    self.tokens.append(tkn)
    return tkn
  }

  isEmpty(line) {
    return self.bMarks[line] + self.tShift[line] >= self.eMarks[line]
  }

  skipEmptyLines(from) {
    iter var max = self.lineMax; from < max; from++ {
      if self.bMarks[from] + self.tShift[from] < self.eMarks[from] {
        break
      }
    }
    return from
  }

  skipSpaces(pos) {
    iter var max = self.src.length(); pos < max; pos++ {
      if !isSpace(self.src[pos]) break
    }
    return pos
  }

  skipSpacesBack(pos, min) {
    if pos <= min return pos
  
    while pos > min {
      if !isSpace(self.src[pos--]) return pos + 1
    }
    return pos
  }

  skipChars(pos, code) {
    iter var max = self.src.length(); pos < max; pos++ {
      if self.src[pos] != code break
    }
    return pos
  }

  skipCharsBack(pos, code, min) {
    if pos <= min return pos
  
    while pos > min {
      if code != self.src[pos--] return pos + 1
    }
    return pos
  }
  
  getLines(begin, end, indent, keepLastLF) {
    var i, lineIndent, ch, first, last, queue, lineStart,
        line = begin
  
    if begin >= end {
      return ''
    }
  
    queue = [nil] * (end - begin)
  
    iter i = 0; line < end; i++ {
      lineIndent = 0
      lineStart = first = self.bMarks[line]
  
      if line + 1 < end or keepLastLF {
        # No need for bounds check because we have fake entry on tail.
        last = self.eMarks[line] + 1
      } else {
        last = self.eMarks[line]
      }
  
      while first < last and lineIndent < indent {
        ch = self.src[first]
  
        if isSpace(ch) {
          if ch == '\t' {
            lineIndent += 4 - (lineIndent + self.bsCount[line]) % 4
          } else {
            lineIndent++
          }
        } else if first - lineStart < self.tShift[line] {
          # patched tShift masked characters to look like spaces (blockquotes, list markers)
          lineIndent++
        } else {
          break
        }
  
        first++
      }
  
      if lineIndent > indent {
        # partially expanding tabs in code blocks, e.g '\t\tfoobar'
        # with indent=2 becomes '  \tfoobar'
        queue[i] = (' ' * (lineIndent - indent)) + self.src[first, last]
      } else {
        queue[i] = self.src[first, last]
      }

      line++
    }
  
    return ''.join(queue)
  }

  var Token = _tkn.Token
}

