import .ruler { Ruler }
import .block


var _rules = [
  # First 2 params - rule name & source. Secondary array - list of rules,
  # which can be terminated by this one.
  [ 'table',      block.table,      [ 'paragraph', 'reference' ] ],
  [ 'code',       block.code ],
  [ 'fence',      block.fence,      [ 'paragraph', 'reference', 'blockquote', 'list' ] ],
  [ 'blockquote', block.blockquote, [ 'paragraph', 'reference', 'blockquote', 'list' ] ],
  [ 'hr',         block.hr,         [ 'paragraph', 'reference', 'blockquote', 'list' ] ],
  [ 'list',       block.list,       [ 'paragraph', 'reference', 'blockquote' ] ],
  [ 'reference',  block.reference ],
  [ 'html_block', block.html_block, [ 'paragraph', 'reference', 'blockquote' ] ],
  [ 'heading',    block.heading,    [ 'paragraph', 'reference', 'blockquote' ] ],
  [ 'lheading',   block.lheading ],
  [ 'paragraph',  block.paragraph ]
]


/** 
 * internal
 * 
 * class ParserBlock
 *
 * Block-level tokenizer.
 */
class ParserBlock {

  /**
   * ParserBlock#ruler
   *
   * [[Ruler]] instance. Keep configuration of block rules.
   * @type Ruler
   */
  var ruler = Ruler()

  ParserBlock() {
    iter var i = 0; i < _rules.length(); i++ {
      self.ruler.push(_rules[i][0], _rules[i][1], { alt: (_rules[i].length() > 2 ? _rules[i][2] : [])[,] })
    }
  }

  /**
   * Generate tokens for input range
   */
  tokenize(state, startLine, endLine) {
    var ok, i, prevLine,
        rules = self.ruler.getRules(''),
        len = rules.length(),
        line = startLine,
        hasEmptyLines = false,
        maxNesting = state.md.options.maxNesting
  
    while line < endLine {
      state.line = line = state.skipEmptyLines(line)
      if line >= endLine break
  
      # Termination condition for nested calls.
      # Nested calls currently used for blockquotes & lists
      if state.sCount[line] < state.blkIndent  break
  
      # If nesting level exceeded - skip tail to the end. That's not ordinary
      # situation and we should not care about content.
      if state.level >= maxNesting {
        state.line = endLine
        break
      }
  
      # Try all possible rules.
      # On success, rule should:
      #
      # - update `state.line`
      # - update `state.tokens`
      # - return true
      prevLine = state.line
  
      iter i = 0; i < len; i++ {
        ok = rules[i](state, line, endLine, false)
        if ok {
          if prevLine >= state.line {
            die Exception("block rule didn't increment state.line")
          }
          break
        }
      }
  
      # this can only happen if user disables paragraph rule
      if !ok die Exception('none of the block rules matched')
  
      # set state.tight if we had an empty line before current tag
      # i.e. latest empty line should not count
      state.tight = !hasEmptyLines
  
      # paragraph might "eat" one newline after it in nested lists
      if state.isEmpty(state.line - 1) {
        hasEmptyLines = true
      }
  
      line = state.line
  
      if line < endLine and state.isEmpty(line) {
        hasEmptyLines = true
        line++
        state.line = line
      }
    }
  }

  /**
   * ParserBlock.parse(str, md, env, outTokens)
   *
   * Process input string and push block tokens into `outTokens`
   */
  parse(src, md, env, outTokens) {
    var state
  
    if !src return
  
    state = self.State(src, md, env, outTokens)
  
    self.tokenize(state, state.line, state.lineMax)
  }

  var State = block.state_block.StateBlock
}

