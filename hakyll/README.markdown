# hakyll-gwark

A fork of [Hakyll](https://github.com/jaspervdj/hakyll) for use with
the [gwark](https://github.com/dbohdan/gwark) lean pandoc fork. Module
names are unchanged from upstream Hakyll; downstream code just changes
its `build-depends` from `hakyll` to `hakyll-gwark`. The fork drops
`Hakyll.Web.Pandoc.Biblio` (citeproc is not part of gwark) and the
reader-dispatch arms for formats gwark doesn't ship (DocBook, Ipynb,
MediaWiki, Org, RST, Textile, AsciiDoc, Djot, Typst); only Html,
LaTeX, and Markdown remain as Pandoc-backed inputs.

The remainder of this README is upstream Hakyll's, kept for reference.

---

# hakyll

Hakyll is a static site generator library in Haskell. More information
(including a tutorial) can be found on
[the hakyll homepage](http://jaspervdj.be/hakyll).

You can install this library using cabal:

    cabal install hakyll

Or using stack:

    stack install hakyll

If Stack fails, please [see which Stackage snapshots contain
Hakyll](https://www.stackage.org/package/hakyll/snapshots) and specify one
explicitly, e.g. `stack install --resolver=lts-22.23 hakyll`.
