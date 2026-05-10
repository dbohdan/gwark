Forked from pandoc upstream commit `12051ec38a433fbea481f7701f1667caf17d0c9b`
(release 3.9.0.2 head of `main` as of fork start), 2026-05-09.

Upstream baseline tag: `upstream-3.9.0.2`.
Pre-LaTeX-prune checkpoint: `pre-latex-prune`.

The fork's cabal package is renamed to **gwark**; the CLI executable
is still named `pandoc` so existing scripts continue to work.

## Baseline (pre-fork)

```
cloc src/ pandoc-cli/src/ pandoc-server/src/ pandoc-lua-engine/src/
Haskell:  281 files,  8990 blank,  9699 comment,  84637 code
```

## Final state (after Phases 1–10)

```
cloc src/ gwark-cli/src/
Haskell:   90 files,  2199 blank,  2717 comment,  22852 code
```

Net deletion: **~73 %** of the Haskell line count (84 637 → 22 852).
Module count: 281 → 90.

| Metric            | Upstream | Plan target (P9) | Actual |
|-------------------|---------:|----------------:|-------:|
| `src/` Haskell LOC|   80 062 |          22 000 | 20 654 |
| Total Haskell LOC |   84 637 |          22 000 | 22 852 |
| Modules in `exposed-modules`        | ~140 | ~40 | 23 |
| `build-depends` count (main library)| ~50  | ~25 | 47 |

(`build-depends` is still close to upstream because we kept the same
set of "general-purpose" Haskell libs — `aeson`, `text`, `mtl`, etc.
The Pandoc-specific deps that went away were `citeproc`,
`pandoc-lua-engine`, `pandoc-lua-marshal`, `djot`, `typst`,
`jira-wiki-markup`, `ipynb`, `asciidoc`, `haddock-library`. Their absence
is what reduces the build time, not the line count.)

## Phase log

- **P0** baseline tag, FORK.md, ghcup install. cloc baseline 84 637 LOC.
- **Phase 1** delete non-essential readers (37 files + 7 dirs). 80 062 → 53 848 LOC.
- **Phase 2** delete non-essential writers (40 files + 4 dirs). 53 848 → 28 647 LOC.
- **Phase 3** cabal cleanup; delete sibling `pandoc-server/`,
  `pandoc-lua-engine/`, `citeproc/` packages; delete unused data dirs
  and templates; delete `data/translations/`.
- **Phase 4** remove citeproc references from `Filter.hs`, `Error.hs`,
  `App/*.hs`. Drop the `citeproc` build-dep.
- **Phase 5** the upstream `Scripting.hs` already shipped a `noEngine`
  stub usable without `pandoc-lua-engine`; no edit needed.
- **Phase 6 (modified)** keep CLI per user request; drop the `lua`,
  `server`, and `repl` flags; always use the `no-lua` and `no-server`
  stubs. Rewrote `gwark-cli/gwark-cli.cabal` to a minimal form.
- **Build fixes** pinned `texmath == 0.13.0.1` and
  `typst-symbols >= 0.1.8.1 && < 0.1.9` (the upstream `texmath` HEAD
  needs a typst-symbols dev API not on Hackage). Re-added
  `commonmark` + `commonmark-pandoc` because `Shared.hs`'s
  `addPandocAttributes` uses them. Dropped `PDF.hs` and made
  `App.hs`'s PDF path throw `PandocPDFError`.
- **Phase 7** trimmed `Readers/LaTeX.hs` from 1423 to ~110 LOC; deleted
  `LaTeX/Citation.hs`, `Inline.hs`, `Lang.hs`, `SIunitx.hs`, `Table.hs`.
  The new `LaTeX.hs` exports only `applyMacros`, `rawLaTeXBlock`, and
  `rawLaTeXInline`. Macro expansion (`+latex_macros`) and raw-tex
  passthrough (`+raw_tex`) verified working. The `latex` input format
  is no longer registered.
- **Phase 8** `verify/ApiSurface.hs` and `verify/Roundtrip.hs`. The
  former imports every Hakyll/Gwern symbol with monomorphic top-level
  bindings; the latter exercises the full `readMarkdown → walk →
  writeHtml5String/writeMarkdown/writePlain` pipeline. Both compile
  cleanly against the fork.
- **Phase 9** SKIPPED. P9.1 (drop `Class/Sandbox`) requires App-layer
  surgery the plan understated. P9.3 (trim `Logging.hs` constructors)
  is high-tedium and most constructors are still referenced by kept
  code. P9.2 / P9.4 (drop HTTP / SelfContained) declined by the user.
- **Phase 10** rename cabal package `pandoc → gwark`,
  `pandoc-cli → gwark-cli`. CLI executable still named `pandoc`.
  `Paths_pandoc → Paths_gwark` in `Version.hs`, `Class/IO.hs`,
  `Data.hs`. Updated `README.md` and added `MAINTENANCE.md`.

## Build smoke tests passing

- `cabal build all` (gwark library + xml-light internal lib + pandoc CLI)
- `pandoc --version` reports `pandoc 3.9.0.2 / Features: -server -lua`.
- `echo '# X' | pandoc -f markdown -t html5` produces `<h1 id="x">X</h1>`.
- `\newcommand{\xx}[1]{X#1X}` followed by `$\xx{42}$` round-trips
  through Markdown reader → AST → HTML writer as `Math InlineMath "X42X"`
  / `\(X42X\)`.
- Raw `\textbf{outer}` round-trips as
  `RawInline (Format "tex") "\\textbf{outer}"`.
- The Phase-8 roundtrip sample (headings, lists, tables, math, footnotes,
  syntax highlighting) emits HTML, Markdown, and plain-text without
  errors.
