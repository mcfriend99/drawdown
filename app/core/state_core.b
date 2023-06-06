# Core state object

import ..token as _tkn

class StateCore {
  StateCore(src, md, env) {
    self.src = src
    self.env = env
    self.tokens = []
    self.inline_mode = false
    self.md = md; # link to parser instance
  }

  # re-export Token class to use in core rules
  var Token = _tkn.Token
}

