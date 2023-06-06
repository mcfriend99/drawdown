# Token class

/**
 * class Token
 */
class Token {

  /**
   * Token#type -> String
   *
   * Type of the token (string, e.g. "paragraph_open")
   */
  var type

  /**
   * Token#tag -> String
   *
   * html tag name, e.g. "p"
   */
  var tag

  /**
   * Token#attrs -> List
   *
   * Html attributes. Format: `[ [ name1, value1 ], [ name2, value2 ] ]`
   */
  var attrs

  /**
   * Token#map -> List
   *
   * Source map info. Format: `[ line_begin, line_end ]`
   */
  var map

  /**
   * Token#nesting -> Number
   *
   * Level change (number in {-1, 0, 1} set), where:
   *
   * -  `1` means the tag is opening
   * -  `0` means the tag is self-closing
   * - `-1` means the tag is closing
   */
  var nesting

  /**
   * Token#level -> Number
   *
   * nesting level, the same as `state.level`
   */
  var level

  /**
   * Token#children -> List
   *
   * A list of child nodes (inline and img tokens)
   */
  var children

  /**
   * Token#content -> String
   *
   * In a case of self-closing tag (code, html, fence, etc.),
   * it has contents of this tag.
   */
  var content

  /**
   * Token#markup -> String
   *
   * '*' or '_' for emphasis, fence string for fence, etc.
   */
  var markup

  /**
   * Token#info -> String
   *
   * Additional information:
   *
   * - Info string for "fence" tokens
   * - The value "auto" for autolink "link_open" and "link_close" tokens
   * - The string value of the item marker for ordered-list "list_item_open" tokens
   */
  var info

  /**
   * Token#meta -> Object
   *
   * A place for plugins to store an arbitrary data
   */
  var meta

  /**
   * Token#block -> Boolean
   *
   * True for block-level tokens, false for inline tokens.
   * Used in renderer to calculate line breaks
   */
  var block

  /**
   * Token#hidden -> Boolean
   *
   * If it's true, ignore this element when rendering. Used for tight lists
   * to hide paragraphs.
   */
  var hidden

  Token(type, tag, nesting) {
    self.type     = type
    self.tag      = tag
    self.attrs    = nil
    self.map      = nil
    self.nesting  = nesting
    self.level    = 0
    self.children = nil
    self.content  = ''
    self.markup   = ''
    self.info     = ''
    self.meta     = nil
    self.block    = false
    self.hidden   = false
  }

  /**
   * Token.attr_index(name) -> Number
   *
   * Search attribute index by name.
   */
  attr_index(name) {
    var attrs, i = 0, len
  
    if !self.attrs return -1
  
    attrs = self.attrs
  
    iter len = attrs.length(); i < len; i++ {
      if attrs[i][0] == name return i
    }
    return -1
  }

  /**
   * Token.attr_push(attr_data)
   *
   * Add `[ name, value ]` attribute to list. Init attrs if necessary
   */
  attr_push(attr_data) {
    if self.attrs {
      self.attrs.append(attr_data)
    } else {
      self.attrs = [ attr_data ]
    }
  }

  /**
   * Token.attr_set(name, value)
   *
   * Set `name` attribute to `value`. Override old value if exists.
   */
  attr_set(name, value) {
    var idx = self.attr_index(name),
        attr_data = [ name, value ]
  
    if idx < 0 {
      self.attr_push(attr_data)
    } else {
      self.attrs[idx] = attr_data
    }
  }

  /**
   * Token.attr_get(name)
   *
   * Get the value of attribute `name`, or nil if it does not exist.
   */
  attr_get(name) {
    var idx = self.attr_index(name), value = nil
    if idx >= 0 {
      value = self.attrs[idx][1]
    }
    return value
  }

  /**
   * Token.attr_join(name, value)
   *
   * Join value to existing attribute via space. Or create new attribute if not
   * exists. Useful to operate with token classes.
   */
  attr_join(name, value) {
    var idx = self.attr_index(name)
  
    if idx < 0 {
      self.attr_push([ name, value ]);
    } else {
      self.attrs[idx][1] = self.attrs[idx][1] + ' ' + value
    }
  }
}

