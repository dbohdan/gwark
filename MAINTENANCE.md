# Maintenance Strategy

Hard fork. Upstream pandoc is **not** tracked automatically. Major
upstream releases will not be merged wholesale. The fork's value is
the smaller surface area and faster build, both of which a blanket
merge would erase.

## Pulling upstream changes

When a relevant upstream change occurs (security fix, Markdown reader
bug, HTML writer regression):

1. `git remote add upstream https://github.com/jgm/pandoc.git`
2. `git fetch upstream`
3. Identify the commits affecting kept files:

   ```
   git log upstream/main -- \
     src/Text/Pandoc/Readers/Markdown.hs \
     src/Text/Pandoc/Readers/HTML.hs \
     src/Text/Pandoc/Writers/HTML.hs \
     src/Text/Pandoc/Writers/Markdown.hs \
     src/Text/Pandoc/Extensions.hs \
     src/Text/Pandoc/Options.hs
   ```

4. Cherry-pick selectively. Conflicts in deleted files don't apply;
   resolve by keeping the deletion side.

## Files that frequently see upstream changes (high-attention)

- `src/Text/Pandoc/Readers/Markdown.hs`
- `src/Text/Pandoc/Readers/HTML.hs` (and the `HTML/` subdirectory)
- `src/Text/Pandoc/Writers/HTML.hs`
- `src/Text/Pandoc/Writers/Markdown.hs` (and the `Markdown/`
  subdirectory)
- `src/Text/Pandoc/Extensions.hs`
- `src/Text/Pandoc/Options.hs`
- `pandoc-types` (Hackage dep, not vendored here)

## Files that rarely change (low-attention)

- `Class/*` hierarchy (`PandocMonad`)
- Parsing infrastructure (`Parsing.hs`, `Parsing/*`)
- The trimmed LaTeX reader (`Readers/LaTeX.hs` + `LaTeX/Macro.hs`,
  `Math.hs`, `Parsing.hs`). Upstream changes here are rare and
  usually orthogonal to the macro / raw subset we kept.

## Things you must not regress

The downstream API contract is documented in `verify/ApiSurface.hs`.
If you change anything that breaks one of those imports, downstream
Hakyll- and Gwern-style consumers will fail to build. Run

```
cabal build all   # builds the lib + the pandoc CLI
```

after any change. To smoke-test the public API, drop
`verify/ApiSurface.hs` and `verify/Roundtrip.hs` into a sibling cabal
project that depends on `gwark` and `pandoc-types`, then `cabal build`.

## Why some upstream features are absent

| Feature | Phase | Reason |
|---|---|---|
| Lua scripting / repl | 5, 6 | not used by Gwern's pipeline; cuts hslua + Lua C deps |
| citeproc | 4 | citations handled downstream by JSON filters |
| `pandoc-server` | 3 | not needed for static-site builds |
| All readers except Markdown / HTML | 1 | only Markdown / HTML are inputs |
| All writers except HTML / Markdown / plain / Markua | 2 | only HTML and Markdown are outputs |
| LaTeX writer + PDF | 2, 3.5 | no PDF output; LaTeX writer was the largest writer |
| LaTeX reader (most of it) | 7 | only the macro engine and raw-passthrough are needed by the Markdown reader's `+latex_macros` and `+raw_tex` extensions |

## Things deferred from upstream's plan

- **P9.1** (drop `Class/Sandbox`): the sandbox is wired into the App
  layer (`--sandbox` CLI flag, sandboxed reader/writer paths). Removing
  it cleanly is a larger surgery than the plan suggested. Saved for
  later.
- **P9.3** (trim `Logging.hs`): most `LogMessage` constructors are
  still referenced by code we kept (Markdown, HTML, Filter, App).
  Trimming requires per-constructor caller analysis. Saved for later.
- **P9.2 / P9.4** (drop HTTP / SelfContained): user opted to keep both,
  since `--self-contained` may be in use.
