# gwark — pandoc lean fork

> _A particular markup converter._

**gwark** is a stripped-down fork of [pandoc][pandoc], maintained
for use with Hakyll-based static site builds (originally for
[Gwern.net](https://gwern.net)). It supports a single workflow:
**Gwerndown ↔ HTML conversion with JSON filters**.

[pandoc]: https://github.com/jgm/pandoc

## What gwark ships

- The **Gwerndown reader** — gwark's name for the dialect that
  pandoc upstream calls "Pandoc's Markdown". Identical to
  upstream's at fork time (release 3.9.0.2); the rename signals
  that gwark may diverge as new features land. Full classical
  extension set, including `+latex_macros` and `+raw_tex`.
- The **HTML reader**.
- A few writers: **HTML5** (and HTML4), **Markdown**, **plain**,
  and **chunked HTML**.
- The **native** (Haskell AST) and **JSON** representations as
  both reader and writer.
- The **JSON filter pipeline** via `Text.Pandoc.Filter` and the
  CLI's `--filter` option.
- The CLI executable **`gwark`** (renamed from `pandoc`).

## What gwark does **not** ship

- The Lua scripting engine or `--lua-filter` (a [provisional Lua
  branch][lua-branch] adds filter support behind a cabal flag;
  the standalone Lua REPL is not exposed even there).
- Citeproc / built-in citation processing.
- The `pandoc-server` HTTP API.
- PDF output.
- Any other reader (DOCX, EPUB, AsciiDoc, RST, Org, Typst, ipynb,
  DocBook, JATS, …).
- Any other writer (LaTeX, DOCX, EPUB, JATS, ConTeXt, RST, Org,
  Typst, asciidoc, slide formats, …).

[lua-branch]: https://github.com/dbohdan/gwark/tree/gwark-lua

The cabal package was renamed from `pandoc` to `gwark`; downstream
consumers must update their `build-depends` accordingly.

Forked from upstream commit `12051ec` (release 3.9.0.2 head of
`main`). Net effect: ~73% deletion of upstream's Haskell line
count (84,637 → ~22,000 LOC, 281 → 90 modules), plus the cleanup
of test/, benchmark/, packaging, and CI scaffolding that no longer
applies.

## Documentation

- [`MANUAL.md`](MANUAL.md) — the user manual, hand-maintained,
  trimmed to what gwark actually does.
- [`gwark-cli/man/gwark.1`](gwark-cli/man/gwark.1) — the man
  page, also hand-maintained.
- [`BUILD.md`](BUILD.md) — how to build from source.
- [`FORK.md`](FORK.md) — rationale for the fork.
- [`AGENTS.md`](AGENTS.md) — guidance for AI coding assistants.
- [`changelog.md`](changelog.md) — gwark's changes on top of the
  upstream history.

## License

GPL-2.0-or-later, same as upstream pandoc. See
[`COPYING.md`](COPYING.md) and [`AUTHORS.md`](AUTHORS.md).

For the full-featured pandoc, see <https://github.com/jgm/pandoc>.
