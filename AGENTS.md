# AGENTS.md

Repository-level guidance for AI coding assistants working on the
**gwark** lean fork of pandoc. Sections are in rough priority order.

## Branch model

The development branch is `main`. Land changes there directly, or
on a topical feature branch (typically `claude/<topic>`) that the
user merges into `main`. There are no other long-lived branches.

The GitHub repository is `dbohdan/gwark` (renamed from
`dbohdan/pandoc`; GitHub redirects the old URL). The git remote
`origin` may still resolve under the old name in sandboxed
environments — leave it alone if it works. The GitHub MCP is
scoped to this repo only; reads or writes against `jgm/pandoc`
will fail.

## Package layout

`cabal.project` lists three packages: `.` (the `gwark`
library — the package was renamed from `pandoc`), `gwark-cli`
(the CLI exe), and `hakyll` (the `hakyll-gwark` package — a fork
of Hakyll targeted at gwark, vendored under `hakyll/`).

The CLI executable is named `gwark`. `cabal list-bin gwark` is
ambiguous because it matches the library — always use
`cabal list-bin gwark-cli:exe:gwark`. The Hakyll fork ships an
`hakyll-gwark-init` exe; `cabal list-bin hakyll-gwark:exe:hakyll-gwark-init`.

Build environment expectation: GHC 9.6.6 in `~/.ghcup/bin`. Most
sessions need `export PATH=~/.ghcup/bin:$PATH` before invoking
cabal.

## Fork invariants — what's gone and shouldn't come back casually

Hard-forked from upstream commit `12051ec` (release 3.9.0.2). The
`upstream-3.9.0.2` git tag is the source for any restoration
cherry-picks.

Removed (Phases 1–9): every reader and writer except Markdown
(Gwerndown — see below), HTML, HTML5/HTML4 writer, Markdown
writer, plain writer, native (JSON), and the full LaTeX reader
(restored after Phase 7 had stripped it). The Markdown reader's
`+latex_macros` and `+raw_tex` extensions go through the LaTeX
reader, and downstream Haskell consumers can use `readLaTeX`
directly to parse mixed LaTeX strings (e.g.\ Arxiv abstracts).
The `latex` *writer* is still gone. Citeproc is gone.
`pandoc-server` is gone. PDF output is gone. The CommonMark
reader is gone — its replacement is `readMarkdown` with
extension flags.

The Markdown dialect that pandoc upstream calls "Pandoc's
Markdown" is rebranded **Gwerndown** in user-facing prose
(README, MANUAL.md, the man page, version banner, cabal
synopsis). The CLI format identifier is unchanged: it's still
`gwark -f markdown -t markdown`. The upstream Markdown sibling
identifiers (`markdown_strict`, `markdown_mmd`,
`markdown_phpextra`, `markdown_github`, `commonmark`,
`commonmark_x`, `gfm`) were dropped — Gwern's pipeline never
references them, and each was just a registry entry routing
through `readMarkdown` / `writeMarkdown` with a different
default extension set.

Lean-fork philosophy: **no backwards-compatibility shims**. If
something is removed, downstream code either adapts or breaks.
Don't add legacy aliases, deprecation wrappers, or "removed"
comments.

## Build gotchas

Data files under `data/` are baked into the binary via
Template Haskell (`embed_data_files`). They **do not trigger
rebuilds when their content changes**. After editing anything
under `data/`, run

    rm -rf dist-newstyle/build/x86_64-linux/ghc-*/gwark-*

(or `rm -rf dist-newstyle` for a full reset) before
`cabal build`.

`cabal exec gwark -- ...` sometimes prepends a `HEAD is now at
...` line on stderr from the cabal store. Tests that capture
both streams must filter or `2>/dev/null`.

`data/translations/en.yaml` is a **required** runtime data file —
removing it resurrects three "translations not found" warnings on
every conversion. It is listed in `gwark.cabal` `data-files`; keep
it there.

`MANUAL.md` is the canonical, hand-maintained user manual. It is
listed in `gwark.cabal` `data-files` and the filename is also
hardcoded in two places: `src/Text/Pandoc/Data.hs` (the runtime
fallback path) and `src/Text/Pandoc/Data/BakedIn.hs` (a TH
`embedFile`). Renaming or moving `MANUAL.md` requires updating
all three. It is the **source of truth**; the man page
(`gwark-cli/man/gwark.1`) is also hand-maintained and was
trimmed in parallel — don't try to regenerate either from
upstream's `manfilter.lua`/`update-readme.lua` (gone).

## Restoration recipes

Anything cherry-picked from `upstream-3.9.0.2` that depends on the
*old* `pandoc` library needs patching — it now depends on
`gwark`. Two known traps:

- `Text.Pandoc.Citeproc` is gone — drop dependent code that
  references it.
- `Text.Pandoc.Readers.readCommonMark` is gone — switch to
  `readMarkdown` with extension flags. The Markdown reader handles
  the commonmark dialect.

When restoring an upstream feature, look at the relevant module
on the `upstream-3.9.0.2` tag, repoint its `build-depends` from
`pandoc` to `gwark`, and trim references to deleted modules.

## What the repo no longer carries

If you go looking for upstream scaffolding and don't find it,
that's intentional. All of the following were deleted as broken
or upstream-only:

- **Build/dev configs**: `Makefile`, `stack.yaml`, `hie.yaml`,
  `flake.nix`, `flake.lock`, `release.nix`, `shell.nix`,
  `.cirrus.yml`, `weeder.toml`. Everything is built with
  `cabal build all` against `cabal.project`.
- **Most of `.github/workflows/`** — the upstream `benchmark`,
  `commit-validation-pr`, `docx-validation`, `format-validation`,
  `nightly`, `release-candidate`, `lint.yml.bkp` workflows are
  gone. A single barebones `ci.yml` survives: it sets up GHC
  9.6.6 on Ubuntu, runs `cabal build all`, smoke-tests the
  `gwark` binary on `# Hi`, and runs the two `verify/` scripts.
- **Packaging** for binary releases: `linux/`, `macos/`,
  `windows/`, `wasm/`. We don't ship binaries.
- **Tooling**: `tools/` (release scripts, Lua filters for
  regenerating MANUAL/README, docx validators) and `man/` (the
  upstream man-page generation pipeline). The man page is
  hand-maintained at `gwark-cli/man/gwark.1`.
- **Tests / benchmarks**: `test/` and `benchmark/` (broken;
  see Tests below).
- **Top-level upstream docs**: `INSTALL.md`, `CONTRIBUTING.md`,
  `SECURITY.md`, `CITATION.cff`, `RELEASE-CHECKLIST-TEMPLATE.org`,
  `README.template`, `PLAN.md`. Most of `doc/` (only
  `filters.md` and `using-the-pandoc-api.md` survive).

If you actually need any of these, reintroduce a minimal version
that matches the lean surface — don't restore the upstream
artefact verbatim. They almost always reference deleted readers,
writers, or packages.

## Maintenance

Hard fork. Upstream pandoc is **not** tracked automatically.
Major upstream releases will not be merged wholesale — the
fork's value is the smaller surface area and faster build, both
of which a blanket merge would erase.

When a relevant upstream change occurs (security fix, Markdown
reader bug, HTML writer regression), pull it as a targeted
cherry-pick:

    git remote add upstream https://github.com/jgm/pandoc.git
    git fetch upstream
    git log upstream/main -- \
      src/Text/Pandoc/Readers/Markdown.hs \
      src/Text/Pandoc/Readers/HTML.hs \
      src/Text/Pandoc/Writers/HTML.hs \
      src/Text/Pandoc/Writers/Markdown.hs \
      src/Text/Pandoc/Extensions.hs \
      src/Text/Pandoc/Options.hs

Cherry-pick selectively. Conflicts in deleted files don't apply;
resolve by keeping the deletion side.

**High-attention files** (frequent upstream changes, watch
closely):

- `src/Text/Pandoc/Readers/Markdown.hs`
- `src/Text/Pandoc/Readers/HTML.hs` (and `Readers/HTML/`)
- `src/Text/Pandoc/Writers/HTML.hs`
- `src/Text/Pandoc/Writers/Markdown.hs` (and
  `Writers/Markdown/`)
- `src/Text/Pandoc/Extensions.hs`
- `src/Text/Pandoc/Options.hs`
- the `pandoc-types` Hackage dep (not vendored)

**Low-attention files** (rarely change upstream):

- `Class/*` (the `PandocMonad` hierarchy)
- Parsing infrastructure (`Parsing.hs`, `Parsing/*`)
- The LaTeX reader (`Readers/LaTeX.hs` plus the helper modules
  under `LaTeX/`: Macro, Math, Parsing, Citation, Inline, Lang,
  SIunitx, Table). It is the full upstream reader; upstream
  changes here are usually orthogonal to gwark's surface area
  but worth tracking.

### Hakyll fork (`hakyll/`)

The `hakyll-gwark` package under `hakyll/` is forked from
`jaspervdj/hakyll@4.17.0.0`, tagged in the repo as
`upstream-hakyll-4.17.0.0`. Cherry-pick upstream Hakyll the same
way:

    git remote add upstream-hakyll https://github.com/jaspervdj/hakyll.git
    git fetch upstream-hakyll
    git log upstream-hakyll/master -- \
      lib/Hakyll/Web/Pandoc.hs \
      lib/Hakyll/Web/Pandoc/FileType.hs

**High-attention files** in the Hakyll fork (mirror gwark's
reader surface; need watching when Hakyll updates):

- `hakyll/lib/Hakyll/Web/Pandoc.hs` — reader case dispatch.
- `hakyll/lib/Hakyll/Web/Pandoc/FileType.hs` — file-extension
  enum.
- `hakyll/hakyll.cabal` — drops `Hakyll.Web.Pandoc.Biblio`, swaps
  `pandoc` → `gwark` build-dep, renames package + init exe.

## Tests

- `verify/ApiSurface.hs`, `verify/Roundtrip.hs` — preserved
  upstream-compat checks.

There is no `test/` tree and no `cabal test`. The upstream
`test-suite test-pandoc` stanza, the matching `test/` fixtures,
and the `benchmark/` stanza were deleted because they depended on
the removed upstream `pandoc` package. Verification is `cabal
build all` plus the scripts under `verify/`; add new checks
there.

`verify/ApiSurface.hs` is the **downstream-API contract**. If a
change breaks one of the imports it exercises, downstream Hakyll-
and Gwern-style consumers fail to build. To smoke-test the public
API, drop `ApiSurface.hs` and `Roundtrip.hs` into a sibling cabal
project that depends on `gwark` and `pandoc-types` and run
`cabal build` there.

## CLI surface

The executable is `gwark`, not `pandoc`. `--version` reports
`Features: -server -lua` and the scripting engine line — use
these to confirm the build.

## Deferred work

Items the lean-down plan called for but didn't land, kept here so
they aren't lost:

- **Drop `Class/Sandbox`** (was upstream phase P9.1). The sandbox
  is wired into the App layer (`--sandbox` CLI flag, sandboxed
  reader/writer paths). Removing it cleanly is larger surgery
  than the original plan suggested.
- **Trim `Logging.hs`** (was P9.3). Most `LogMessage`
  constructors are still referenced by code we kept (Markdown,
  HTML, Filter, App). Trimming requires per-constructor caller
  analysis.
- **HTTP and `--self-contained`** (P9.2 / P9.4 in the original
  plan): kept by user choice, since `--self-contained` may be in
  use downstream.

## Conventions

Commits: imperative subject, body in bullet points explaining
what and why (e.g. "Phase N: ...", "Restore X", "Drop Y"). One
logical change per commit so reverts stay clean.

Don't create PRs unless explicitly asked. Don't invoke
`ultrareview` (user-triggered only).
