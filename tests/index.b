import ..app
import json

var md = app.Markdown('commonmark')
/* var start = microtime()
file('test.html', 'w').write(md.render(file('test.md').read()))
echo 'Completed in ${(microtime() - start) / 1000000}s' */
/* var tests = json.decode(file('commonmark.0.30.json').read())

describe('Markdown Test', @() {
  it('should all pass', @() {
    for test in tests {
      expect(md.render(test.markdown)).to_be(test.html)
    }
  })
}) */
echo md.render('<table><tr><td>\n<pre>\n**Hello**,\n\n_world_.\n</pre>\n</td></tr></table>\n')
/* echo md.render('
### [Footnotes](https://github.com/markdown-it/markdown-it-footnote)

Footnote 1 link[^first].

Footnote 2 link[^second].

Inline footnote^[Text of inline footnote] definition.

Duplicated footnote reference[^second].

[^first]: Footnote **can have markup**

    and multiple paragraphs.

[^second]: Footnote text.


### [Definition lists](https://github.com/markdown-it/markdown-it-deflist)

Term 1

:   Definition 1
with lazy continuation.

Term 2 with *inline markup*

:   Definition 2

        { some code, part of Definition 2 }

    Third paragraph of definition 2.

_Compact style:_

Term 1
  ~ Definition 1

Term 2
  ~ Definition 2a
  ~ Definition 2b
') */

