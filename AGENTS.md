# AGENTS.md

Repository-level guidance for AI coding assistants working on the
**gwark** lean fork of pandoc. Sections are in rough priority order.

## Branch model

There are two long-lived development branches: a **baseline** (no
Lua) and a **Lua branch** that adds Lua filter support behind a
cabal flag. The Lua branch is provisional — it may or may not
remain a permanent fixture of the repository, so default to
landing changes on the baseline branch. Merge or cherry-pick into
the Lua branch only when a change has to live there too.

Don't push to `main`. New work goes on the baseline branch (or a
feature branch off it).

The remote `origin` is `dbohdan/pandoc`. The GitHub MCP is scoped
to that repo only — reads or writes against `jgm/pandoc` will
fail.

## Package layout

`cabal.project` always lists `.` (the `gwark` library — the
package was renamed from `pandoc`) and `gwark-cli`. The Lua
branch additionally lists `pandoc-lua-engine` (the upstream
sibling package, repointed at `gwark`).

The CLI executable is named `gwark`. `cabal list-bin gwark` is
ambiguous because it matches the library — always use
`cabal list-bin gwark-cli:exe:gwark`.

Build environment expectation: GHC 9.6.6 in `~/.ghcup/bin`. Most
sessions need `export PATH=~/.ghcup/bin:$PATH` before invoking
cabal.

## Fork invariants — what's gone and shouldn't come back casually

Hard-forked from upstream commit `12051ec` (release 3.9.0.2). The
`upstream-3.9.0.2` git tag is the source for any restoration
cherry-picks.

Removed (Phases 1–9): every reader and writer except Markdown
(Gwerndown — see below), HTML, HTML5/HTML4 writer, Markdown
writer, plain writer, Markua writer, native (JSON). The LaTeX
reader is kept in stripped form **only** for the Markdown
reader's `+latex_macros` and `+raw_tex` extensions. Citeproc is
gone. `pandoc-server` is gone. PDF output is gone. The
CommonMark reader is gone — its replacement is `readMarkdown`
with extension flags.

The Markdown dialect that pandoc upstream calls "Pandoc's
Markdown" is rebranded **Gwerndown** in user-facing prose
(README, MANUAL.md, the man page, version banner, cabal
synopsis). The CLI format identifier is unchanged: it's still
`gwark -f markdown -t markdown`. Sibling identifiers
(`markdown_strict`, `markdown_mmd`, `markdown_phpextra`,
`commonmark`, `commonmark_x`, `gfm`) keep their upstream names.

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
every conversion. On the Lua branch, `data/init.lua` is also
required (the Lua engine sources it on every run). Both are
listed in `gwark.cabal` `data-files`; keep them there.

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
`gwark`. Two known traps in `pandoc-lua-engine` are already
applied on the Lua branch and document the pattern:

- `Text.Pandoc.Citeproc` is gone — drop dependent Lua bindings
  (`pandoc.utils.citeproc`, `pandoc.utils.references`).
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
- **CI**: `.github/workflows/` is gone. Nothing runs on push
  or PR; verification is manual.
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

## Tests

- `verify/ApiSurface.hs`, `verify/Roundtrip.hs` — preserved
  upstream-compat checks.
- `verify/lua/run-tests.sh` (Lua branch only) — five-check shell
  smoke test for `--lua-filter`.

There is no `test/` tree, no `cabal test`, and no CI. The
upstream `test-suite test-pandoc` stanza, the matching `test/`
fixtures, and the `benchmark/` stanza were deleted because they
depended on the removed upstream `pandoc` package. Verification
is manual: build (`cabal build all`), run a smoke conversion,
optionally run the scripts under `verify/`. Add new checks under
`verify/`.

## CLI surface

The executable is `gwark`, not `pandoc`. `--version` reports
`Features: -server [+/-]lua` and the scripting engine line — use
these to confirm which build is in your hands.

## Conventions

Commits: imperative subject, body in bullet points explaining
what and why (e.g. "Phase N: ...", "Restore X", "Re-add Y behind
a flag"). One logical change per commit so reverts stay clean —
the translation-fix and Lua-restore commits are split for exactly
this reason.

Don't create PRs unless explicitly asked. Don't invoke
`ultrareview` (user-triggered only).
