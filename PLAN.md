# Pandoc Lean Fork — Operations Manual for Claude Code

## Context (do not skip)

You are reducing Pandoc 3.9.0.2 to a focused subset that supports a single workflow: **Pandoc Markdown ↔ HTML conversion with JSON filters**, used as a Haskell library by Hakyll-based static site builds. Lua filters, all non-Markdown/HTML readers and writers, citeproc, and the full LaTeX reader are out of scope. The downstream consumer is Gwern.net (`gwern/gwern.net`), whose `build/` directory is ~37,700 LOC of Haskell that imports Pandoc as a library and walks the AST directly via `walk`, `walkM`, `query`, `queryWith`, `topDown`, `bottomUpM`. Hakyll itself depends on a narrow Pandoc surface (see Phase 8) and will be forked separately; your job here is the Pandoc fork only.

Targets:
- ~80,000 LOC in `src/` → ~27,000 LOC
- ~110,000 LOC including vendored deps → ~50,000 LOC under direct control
- Build time approximately halved
- Public `Text.Pandoc.*` API surface unchanged for the symbols Hakyll and Gwern's build use (enumerated in Phase 8)

The order of phases matters. Bulk deletion is mechanical and safe; the LaTeX reader prune is delicate and goes last. Do not skip the verification step at the end of any phase.

## Pre-flight

### P0.1 — Repository setup

```bash
git clone https://github.com/jgm/pandoc.git pandoc-lean
cd pandoc-lean
git checkout -b lean-fork
git tag upstream-3.9.0.2 HEAD
```

Confirm you are at commit pinned to release 3.9.0.2 or HEAD as of your starting date. Record the hash in `FORK.md` at the repo root (create this file now with one line: `Forked from pandoc upstream commit <hash>, <date>.`). Add and commit.

### P0.2 — Baseline build verification

Run a baseline build to confirm the upstream tree builds cleanly in this environment before you start modifying it:

```bash
cabal update
cabal build pandoc 2>&1 | tail -20
```

If the upstream tree fails to build, **stop and ask the user** before proceeding. Do not attempt to fix upstream build issues; that's a separate problem.

If it succeeds, record the build output line count and time in `FORK.md` for later comparison.

### P0.3 — Tooling

Install `cloc` for measurements: `apt-get install -y cloc` or equivalent. You will use it at the end of each phase to verify size targets.

### P0.4 — API compatibility checklist (reference, do not modify)

The following symbols MUST remain exported from `Text.Pandoc` (or its sub-modules at their current paths) at the end of all phases. This list is authoritative — if a phase would break any of these, stop and reconsider.

```
-- From Text.Pandoc (umbrella module)
runPure, def, Pandoc(..), Block(..), Inline(..), Format(..)
nullMeta, nullAttr, MathType(..)
ReaderOptions, WriterOptions
readerExtensions, writerExtensions, writerColumns, writerSectionDivs
writerTableOfContents, writerHTMLMathMethod, writerHighlightMethod
HTMLMathMethod(..), defaultMathJaxURL
WrapPreserve, Skylighting
readMarkdown, readHtml
writeMarkdown, writePlain, writeHtml5String

-- From Text.Pandoc.Walk
walk, walkM, query, queryWith

-- From Text.Pandoc.Builder
setMeta, Blocks, Inlines, plus the smart constructors

-- From Text.Pandoc.Extensions
pandocExtensions, enableExtension, disableExtension
Extension(Ext_smart, Ext_literate_haskell, Ext_shortcut_reference_links, ...)

-- From Text.Pandoc.Highlighting
pygments  -- (used by Hakyll's defaultHakyllWriterOptions)

-- From Text.Pandoc.Class (Pandoc.Class.PandocPure, Pandoc.Class.PandocMonad)
runPure, PandocMonad

-- From Text.Pandoc.Filter
applyFilters

-- topDown, bottomUpM are from Text.Pandoc.Generic (still in pandoc-types)
```

If you ever need to remove an export here, stop and ask.

---

## Phase 1 — Delete non-essential readers

### Goal
Remove all readers except Markdown, HTML, LaTeX, Metadata, and Native. The LaTeX reader is kept for now because the Markdown reader imports `applyMacros`, `rawLaTeXBlock`, `rawLaTeXInline` from it; we will trim it in Phase 7.

### Files to delete

```
src/Text/Pandoc/Readers/AsciiDoc.hs
src/Text/Pandoc/Readers/BibTeX.hs
src/Text/Pandoc/Readers/CSV.hs
src/Text/Pandoc/Readers/CommonMark.hs
src/Text/Pandoc/Readers/Creole.hs
src/Text/Pandoc/Readers/CslJson.hs
src/Text/Pandoc/Readers/Djot.hs
src/Text/Pandoc/Readers/DocBook.hs
src/Text/Pandoc/Readers/Docx.hs
src/Text/Pandoc/Readers/Docx/  (entire directory)
src/Text/Pandoc/Readers/DokuWiki.hs
src/Text/Pandoc/Readers/EPUB.hs
src/Text/Pandoc/Readers/EndNote.hs
src/Text/Pandoc/Readers/FB2.hs
src/Text/Pandoc/Readers/Haddock.hs
src/Text/Pandoc/Readers/HaddockLex.hs  (if present)
src/Text/Pandoc/Readers/Ipynb.hs
src/Text/Pandoc/Readers/JATS.hs
src/Text/Pandoc/Readers/Jira.hs
src/Text/Pandoc/Readers/MediaWiki.hs
src/Text/Pandoc/Readers/Mdoc.hs
src/Text/Pandoc/Readers/Muse.hs
src/Text/Pandoc/Readers/ODT.hs
src/Text/Pandoc/Readers/ODT/  (entire directory)
src/Text/Pandoc/Readers/OPML.hs
src/Text/Pandoc/Readers/Org.hs
src/Text/Pandoc/Readers/Org/  (entire directory)
src/Text/Pandoc/Readers/Pod.hs
src/Text/Pandoc/Readers/Pptx.hs
src/Text/Pandoc/Readers/RIS.hs
src/Text/Pandoc/Readers/RST.hs
src/Text/Pandoc/Readers/Roff.hs
src/Text/Pandoc/Readers/RTF.hs
src/Text/Pandoc/Readers/TWiki.hs
src/Text/Pandoc/Readers/Textile.hs
src/Text/Pandoc/Readers/TikiWiki.hs
src/Text/Pandoc/Readers/Txt2Tags.hs
src/Text/Pandoc/Readers/Typst.hs
src/Text/Pandoc/Readers/Typst/  (entire directory)
src/Text/Pandoc/Readers/Vimwiki.hs
src/Text/Pandoc/Readers/Xlsx.hs
```

Use `find src/Text/Pandoc/Readers -maxdepth 1 -type f` to get the actual current list before deleting; the upstream tree may have additions or removals you should reconcile. **Keep**: `Markdown.hs`, `Metadata.hs`, `Native.hs`, `HTML.hs`, `HTML/` directory, `LaTeX.hs`, `LaTeX/` directory.

### Steps

1. Delete each file/directory listed above with `git rm`.
2. Open `src/Text/Pandoc/Readers.hs`. This is the dispatch table that maps format strings to reader functions. Remove every entry whose target reader has been deleted. Keep entries for `markdown`, `html`, `latex`, `native`, and any format aliases that map to these (e.g., `markdown_strict`, `markdown_phpextra`, `markdown_mmd`, `markdown_github`, `commonmark` — the Markdown reader handles all of these via extension flags). Remove `commonmark_x`, `gfm`, `bibtex`, `csv`, etc.
3. Remove the corresponding `import` statements at the top of `Readers.hs`.
4. Some test files in `test/Tests/Readers/` reference the deleted readers. Delete the corresponding test files: anything matching the pattern of a deleted reader.

### Verification

```bash
cabal build pandoc 2>&1 | tee /tmp/phase1-build.log | tail -30
```

Expected: build will fail because `pandoc.cabal` still lists deleted modules in `exposed-modules`. That's Phase 2. For now, just verify that errors are about missing modules and not about dangling references in non-deleted files. If you see import errors in `Markdown.hs`, `HTML.hs`, `LaTeX.hs`, or `Readers.hs`, stop and investigate.

### Commit

```
git add -A
git commit -m "Phase 1: delete non-essential readers

Removed all readers except Markdown, HTML, LaTeX, Metadata, Native.
LaTeX reader retained because Readers/Markdown.hs imports applyMacros,
rawLaTeXBlock, rawLaTeXInline from it. Will trim in Phase 7."
```

---

## Phase 2 — Delete non-essential writers

### Goal
Remove all writers except those needed for HTML and Markdown output paths.

### Files to delete

```
src/Text/Pandoc/Writers/ANSI.hs
src/Text/Pandoc/Writers/AsciiDoc.hs
src/Text/Pandoc/Writers/BBCode.hs
src/Text/Pandoc/Writers/BibTeX.hs
src/Text/Pandoc/Writers/CommonMark.hs
src/Text/Pandoc/Writers/ConTeXt.hs
src/Text/Pandoc/Writers/CslJson.hs
src/Text/Pandoc/Writers/Djot.hs
src/Text/Pandoc/Writers/DocBook.hs
src/Text/Pandoc/Writers/Docx.hs
src/Text/Pandoc/Writers/DokuWiki.hs
src/Text/Pandoc/Writers/EPUB.hs
src/Text/Pandoc/Writers/FB2.hs
src/Text/Pandoc/Writers/Haddock.hs
src/Text/Pandoc/Writers/ICML.hs
src/Text/Pandoc/Writers/Ipynb.hs
src/Text/Pandoc/Writers/JATS.hs
src/Text/Pandoc/Writers/Jira.hs
src/Text/Pandoc/Writers/LaTeX.hs
src/Text/Pandoc/Writers/LaTeX/  (entire directory)
src/Text/Pandoc/Writers/Man.hs
src/Text/Pandoc/Writers/MediaWiki.hs
src/Text/Pandoc/Writers/Ms.hs
src/Text/Pandoc/Writers/Muse.hs
src/Text/Pandoc/Writers/ODT.hs
src/Text/Pandoc/Writers/OOXML.hs
src/Text/Pandoc/Writers/OPML.hs
src/Text/Pandoc/Writers/OpenDocument.hs
src/Text/Pandoc/Writers/Org.hs
src/Text/Pandoc/Writers/Powerpoint.hs
src/Text/Pandoc/Writers/Powerpoint/  (entire directory)
src/Text/Pandoc/Writers/RST.hs
src/Text/Pandoc/Writers/RTF.hs
src/Text/Pandoc/Writers/Roff.hs
src/Text/Pandoc/Writers/TEI.hs
src/Text/Pandoc/Writers/Texinfo.hs
src/Text/Pandoc/Writers/Textile.hs
src/Text/Pandoc/Writers/Typst.hs
src/Text/Pandoc/Writers/Vimdoc.hs
src/Text/Pandoc/Writers/XML.hs
src/Text/Pandoc/Writers/XWiki.hs
src/Text/Pandoc/Writers/ZimWiki.hs
```

**Keep**: `HTML.hs`, `Blaze.hs`, `ChunkedHTML.hs`, `Markdown.hs`, `Markdown/` directory (contains `Inline.hs`, `Table.hs`, `Types.hs`), `Native.hs`, `Math.hs`, `Shared.hs`, `AnnotatedTable.hs`, `GridTable.hs`.

### Steps

1. Delete files/directories.
2. Edit `src/Text/Pandoc/Writers.hs` (the dispatch table). Remove every entry for deleted writers. Keep `html`, `html4`, `html5`, `markdown`, `markdown_strict`, `markdown_phpextra`, `markdown_mmd`, `markdown_github`, `commonmark` (the Markdown writer handles these via extensions), `plain` (this is `writePlain` — lives inside `Writers/Markdown.hs`, not a separate writer), `native`. If `chunkedhtml` is listed, keep it.
3. Remove corresponding imports at the top of `Writers.hs`.
4. Delete corresponding test files in `test/Tests/Writers/`.

### Verification

```bash
cabal build pandoc 2>&1 | tee /tmp/phase2-build.log | tail -30
```

Errors at this stage will still be about cabal-listed modules that don't exist. Verify no dangling imports in kept files. If `Writers/HTML.hs` or `Writers/Markdown.hs` reference a deleted writer, stop — that means an interdependency we missed.

### Commit

```
git add -A
git commit -m "Phase 2: delete non-essential writers

Kept HTML (+Blaze, ChunkedHTML), Markdown (+Inline, Table, Types),
Native, Math, Shared, AnnotatedTable, GridTable. writePlain lives
in Writers/Markdown.hs and is preserved."
```

---

## Phase 3 — Cabal file cleanup

### Goal
Make `pandoc.cabal` reflect the deletions so the build proceeds.

### Steps

1. Open `pandoc.cabal`. Locate the `library` section's `exposed-modules` list. Remove every entry whose source file you deleted in Phases 1-2. The list is alphabetical; this is mostly mechanical.
2. In the same `library` section, find `other-modules` and do the same.
3. Find the `build-depends` block. Remove these lines:
   - `pandoc-lua-marshal`
   - `pandoc-lua-engine`
   - `citeproc`
   - `tagsoup` is used by HTML reader — **keep**
   - `texmath` — **keep** (we are deferring the texmath drop decision)
   - `skylighting`, `skylighting-core` — **keep**
   - `xml`, `xml-light` — **keep** (XML.hs uses them)
   - `JuicyPixels`, `mtl`, `aeson`, `attoparsec`, `text`, etc. — **keep** (core deps)
   - Any dep that was only pulled in by deleted writers (e.g., `zip-archive` for Docx, `Glob` for some readers) — these will surface as unused; remove on a second pass.
4. Open `cabal.project` at the repo root. Remove the `pandoc-lua-engine` source-repository-package block and any related `package pandoc-lua-engine` configuration.
5. In `pandoc.cabal`, also remove the executable `pandoc` block's references to deleted modules if any are listed there.
6. Locate `data-files` section. Delete entries:
   - All `data/templates/*` except `default.html5`, `default.html4`, `default.chunkedhtml`, `styles.html`, `styles.citations.html`
   - All `data/translations/*` (keep if you want i18n; safe to delete for English-only)
   - `data/abbreviations/*` — keep (used by Markdown reader's smart-quote handling)
   - `data/creole.lua`, `data/init.lua` — delete
   - `data/default.csl` — delete
   - `data/docbook-entities.txt` — keep (HTML entity table, used by HTML reader/writer)
   - `data/docx/`, `data/odt/`, `data/pptx/`, `data/dzslides/`, `data/epub.css` — delete entire directories/files
7. Delete the corresponding files from disk: `git rm -r data/docx/ data/odt/ data/pptx/ data/dzslides/ data/epub.css data/creole.lua data/init.lua data/default.csl` and the templates not on the keep list.

### Verification

```bash
cabal build pandoc 2>&1 | tee /tmp/phase3-build.log | tail -50
```

You should see new errors now: dangling imports in kept files that reference deleted modules. Common ones:
- `src/Text/Pandoc/Filter.hs` imports `Text.Pandoc.Citeproc (processCitations)` and `Text.Pandoc.Scripting (ScriptingEngine)` — these are Phases 4 and 5.
- `src/Text/Pandoc/App.hs` and `src/Text/Pandoc/App/*` import many deleted writers/readers — Phase 6.
- `src/Text/Pandoc/PDF.hs` imports the LaTeX writer — delete this file (`git rm src/Text/Pandoc/PDF.hs` and remove from cabal).
- `src/Text/Pandoc/SelfContained.hs` is OK; review and keep unless you're sure Gwern doesn't use `--self-contained`.

If errors are anything other than the expected "Module X cannot be found" or "Could not find module" cascade from the deletions, stop and investigate.

### Commit

```
git add -A
git commit -m "Phase 3: cabal cleanup, drop pandoc-lua-engine and citeproc

Removed deleted modules from exposed-modules and other-modules.
Dropped pandoc-lua-engine, pandoc-lua-marshal, citeproc from
build-depends. Removed Lua-related data files and unused templates.
Build now fails on dangling Citeproc/Scripting references in
Filter.hs (handled in Phases 4-5)."
```

---

## Phase 4 — Remove citeproc

### Goal
Eliminate the citeproc dependency. Citation nodes (`Cite ...`) in the AST will pass through unprocessed; downstream consumers handle citations themselves.

### Files to delete

```
src/Text/Pandoc/Citeproc.hs
src/Text/Pandoc/Citeproc/  (entire directory)
```

### Steps

1. Delete the files above.
2. Open `src/Text/Pandoc/Filter.hs`. Find the import `import Text.Pandoc.Citeproc (processCitations)`. Delete it.
3. In the same file, find every call to `processCitations`. There is typically one call, inside `applyFilters` or a similar pipeline function. Delete the call. The `Pandoc -> PandocMonad m => m Pandoc` pipeline simply skips this step.
4. Search for other importers of `Text.Pandoc.Citeproc` across `src/`:
   ```
   grep -rln 'Text.Pandoc.Citeproc' src/
   ```
   Anywhere it appears, delete the import. If a function body uses citeproc machinery, replace with `pure id` or remove the call.
5. Remove `data/default.csl` (already done in Phase 3 — verify).
6. Update `pandoc.cabal` if `Text.Pandoc.Citeproc` is in `exposed-modules` (it should already be removed in Phase 3 — verify).

### Verification

```bash
cabal build pandoc 2>&1 | tee /tmp/phase4-build.log | tail -30
grep -rn 'Citeproc\|processCitations' src/  # Should be empty
```

### Commit

```
git add -A
git commit -m "Phase 4: remove citeproc

Deleted src/Text/Pandoc/Citeproc.hs and Citeproc/ directory.
Stripped processCitations call from Filter.hs. Cite nodes now
pass through the AST unprocessed."
```

---

## Phase 5 — Stub Lua/Scripting interface

### Goal
Remove all Lua dependencies. The `Scripting` interface stays as a no-op so `Filter.hs` compiles without changes to its outer signature.

### Steps

1. Open `src/Text/Pandoc/Scripting.hs`. Replace its entire contents with a minimal stub:

```haskell
{-# LANGUAGE OverloadedStrings #-}
-- | Scripting engine stub. The lean fork does not support Lua filters.
-- All script-engine operations return errors. JSON filters are
-- handled directly by Text.Pandoc.Filter.JSON.
module Text.Pandoc.Scripting
  ( ScriptingEngine(..)
  , noEngine
  ) where

import Text.Pandoc.Definition (Pandoc)
import Text.Pandoc.Class.PandocMonad (PandocMonad)
import Text.Pandoc.Error (PandocError(..))
import qualified Data.Text as T
import Control.Monad.Except (throwError)

-- | Opaque scripting engine. The lean fork has no Lua engine; all
-- methods return errors.
data ScriptingEngine = ScriptingEngine
  { engineName        :: T.Text
  , engineApplyFilter :: forall m. PandocMonad m
                      => [(T.Text, T.Text)] -> [String] -> FilePath
                      -> Pandoc -> m Pandoc
  }

-- | The null scripting engine. Use this where a 'ScriptingEngine'
-- is required but no Lua support is wanted.
noEngine :: ScriptingEngine
noEngine = ScriptingEngine
  { engineName = "none"
  , engineApplyFilter = \_ _ _ _ ->
      throwError $ PandocAppError
        "Lua filters not supported in lean fork; use JSON filters."
  }
```

If the existing `ScriptingEngine` type signature in upstream differs from the above (it sometimes uses additional fields), preserve the field names and types upstream uses, but make every method body return the `PandocAppError` shown above. The goal is a type-compatible stub.

2. Search for callers of Lua-specific machinery:
   ```
   grep -rln 'pandoc-lua-engine\|HsLua\|Text.Pandoc.Lua\|hslua' src/
   ```
   If any results appear, delete those imports. Replace any `engineFromHsLua` or similar calls with `noEngine`.
3. In `src/Text/Pandoc/App.hs` (if you haven't deleted it yet — Phase 6), replace any `engineFromLua`/`hsluaEngine` reference with `noEngine`.

### Verification

```bash
cabal build pandoc 2>&1 | tee /tmp/phase5-build.log | tail -30
grep -rn 'HsLua\|hslua\|Text.Pandoc.Lua' src/  # Should be empty
```

### Commit

```
git add -A
git commit -m "Phase 5: stub scripting engine, drop Lua

Replaced Text.Pandoc.Scripting with a no-op ScriptingEngine.
JSON filters via Text.Pandoc.Filter.JSON remain functional;
Lua filters return PandocAppError if invoked."
```

---

## Phase 6 — Strip the App layer

### Goal
The lean fork is a library only. Hakyll consumes Pandoc via `Text.Pandoc.readMarkdown`, `writeHtml5String`, etc. — the CLI executable is not needed for Gwern's pipeline. Removing it eliminates ~2,700 LOC of option-parsing plumbing and several CLI-only deps.

### Steps

1. Delete:
   ```
   src/Text/Pandoc/App.hs
   src/Text/Pandoc/App/  (entire directory)
   app/  (the executable Main module, usually app/pandoc.hs)
   ```
2. In `pandoc.cabal`, delete the entire `executable pandoc` block.
3. Remove `Text.Pandoc.App` from `exposed-modules` if present.
4. Some deps were CLI-only and can now be dropped from `build-depends`:
   - `optparse-applicative` (likely)
   - `process` (verify — may be used elsewhere)
   Check by `grep -rln 'import.*Optparse\|optparse-applicative' src/`. Remove only deps with no remaining usage.

### Verification

```bash
cabal build pandoc 2>&1 | tee /tmp/phase6-build.log | tail -30
```

The library should now build clean. If there are still errors, they are most likely:
- Missing modules in `exposed-modules` (cabal complains about a module listed but not on disk, or a module on disk but not listed)
- Unused-import warnings — these are tolerable, fix at end

If the build succeeds, run a smoke test:

```bash
cat > /tmp/smoke.hs <<'EOF'
import Text.Pandoc
import Data.Text (Text)
import qualified Data.Text.IO as T

main :: IO ()
main = do
  let md = "# Hello\n\nThis is *Markdown* with `code`.\n"
  result <- runIO $ do
    pandoc <- readMarkdown def{readerExtensions = pandocExtensions} md
    writeHtml5String def pandoc
  case result of
    Left e -> error (show e)
    Right html -> T.putStrLn html
EOF
cabal exec runghc -- /tmp/smoke.hs
```

Expected output: an HTML rendering of the input markdown. If this fails, the library is broken; investigate before continuing.

### Commit

```
git add -A
git commit -m "Phase 6: strip CLI/App layer, library-only fork

Deleted src/Text/Pandoc/App.hs, App/, and app/. Removed
executable block from pandoc.cabal. Library smoke-tested
with readMarkdown -> writeHtml5String."
```

---

## Phase 7 — LaTeX reader prune (delicate)

### Goal
The Markdown reader imports three things from `Text.Pandoc.Readers.LaTeX`: `applyMacros`, `rawLaTeXBlock`, `rawLaTeXInline`. The full LaTeX reader is 4,847 LOC across 8 files; we only need the macro engine and a slimmed raw-LaTeX detector. Target: keep ~2,000 LOC, delete ~2,800 LOC.

**This phase is the riskiest.** Make a checkpoint commit before starting (`git tag pre-latex-prune`), and be prepared to revert if the prune breaks behavior.

### Files to delete

```
src/Text/Pandoc/Readers/LaTeX/Citation.hs
src/Text/Pandoc/Readers/LaTeX/Inline.hs
src/Text/Pandoc/Readers/LaTeX/Lang.hs
src/Text/Pandoc/Readers/LaTeX/SIunitx.hs
src/Text/Pandoc/Readers/LaTeX/Table.hs
```

### Files to keep, untouched

```
src/Text/Pandoc/Readers/LaTeX/Macro.hs   (235 LOC — \newcommand engine)
src/Text/Pandoc/Readers/LaTeX/Math.hs    (253 LOC — math env recognition)
src/Text/Pandoc/Readers/LaTeX/Parsing.hs (1182 LOC — LaTeX tokenizer)
```

### File to trim heavily

`src/Text/Pandoc/Readers/LaTeX.hs` (1,423 LOC → target ~350 LOC).

### Steps

1. Delete the five files above.
2. Open `src/Text/Pandoc/Readers/LaTeX.hs`. Identify the three exports the Markdown reader actually uses:
   ```
   grep 'rawLaTeXBlock\|rawLaTeXInline\|applyMacros' src/Text/Pandoc/Readers/Markdown.hs
   ```
3. The current `LaTeX.hs` exports a much larger surface (`readLaTeX`, command tables, environment handlers, etc.). Reduce its `module Text.Pandoc.Readers.LaTeX (...)` export list to:
   ```haskell
   module Text.Pandoc.Readers.LaTeX
     ( applyMacros
     , rawLaTeXBlock
     , rawLaTeXInline
     ) where
   ```
4. Delete the function definitions for everything else in the file: `readLaTeX`, the command-dispatch tables (`inlineCommands`, `blockCommands`), environment handlers (other than what `Math.hs` provides), and helper functions used only by deleted code. Use the compiler as your guide: after each deletion, `cabal build` and follow the "defined but not used" warnings.
5. The three retained functions have transitive helpers. The minimal set:
   - `applyMacros` needs the macro environment (from `Macro.hs`) and the LaTeX tokenizer (from `Parsing.hs`).
   - `rawLaTeXBlock` and `rawLaTeXInline` need to recognize: (a) macro definitions (`\newcommand`, `\def`, `\renewcommand`, `\providecommand`, `\let`); (b) math environments (handed to `Math.hs`); (c) opaque commands (any `\foo{...}` is treated as RawInline `tex` and passed through).
   - For (c), you do NOT need the full upstream command table. Replace the upstream command-dispatch with a minimal version that:
     - Recognizes the macro-definition primitives and dispatches to `Macro.hs`
     - Recognizes math-mode triggers (`\(`, `\[`, `\begin{equation}`, etc.) and dispatches to `Math.hs`
     - Falls through everything else as RawInline (Format "tex") containing the literal source
6. Edit `src/Text/Pandoc/Readers/LaTeX/Math.hs` if it imports anything from the deleted files (`Inline.hs`, `Citation.hs`). If it does, isolate or inline the needed helpers locally.
7. Edit `src/Text/Pandoc/Readers/LaTeX/Parsing.hs` similarly — it should be self-contained but verify.
8. Update `pandoc.cabal` to remove the deleted modules from `other-modules`.

### Verification

This phase requires more rigorous testing because it changes parser behavior, not just removes unused code.

1. Build:
   ```bash
   cabal build pandoc 2>&1 | tee /tmp/phase7-build.log | tail -30
   ```

2. Macro test — confirm `+latex_macros` still works:
   ```bash
   cat > /tmp/macro_test.hs <<'EOF'
   import Text.Pandoc
   import qualified Data.Text.IO as T
   main :: IO ()
   main = do
     let md = "\\newcommand{\\xx}[1]{X#1X}\n\nThe value is $\\xx{42}$.\n"
     result <- runIO $ do
       p <- readMarkdown def{readerExtensions = pandocExtensions} md
       writeHtml5String def{writerHTMLMathMethod = MathJax defaultMathJaxURL} p
     case result of
       Left e -> error (show e)
       Right html -> T.putStrLn html
   EOF
   cabal exec runghc -- /tmp/macro_test.hs
   ```
   Expected: HTML output where the math contains `X42X` (macro expanded) inside MathJax delimiters.

3. Raw-tex test — confirm passthrough still works:
   ```bash
   cat > /tmp/raw_test.hs <<'EOF'
   import Text.Pandoc
   import qualified Data.Text.IO as T
   main :: IO ()
   main = do
     let md = "Inline \\textbf{bold} via raw tex.\n"
     result <- runIO $ do
       p <- readMarkdown def{readerExtensions = pandocExtensions} md
       writeMarkdown def{writerExtensions = pandocExtensions} p
     case result of
       Left e -> error (show e)
       Right out -> T.putStrLn out
   EOF
   cabal exec runghc -- /tmp/raw_test.hs
   ```
   Expected: roundtrip preserves the `\textbf{bold}` literal in the output.

4. Round-trip test against a real Markdown sample (a Gwern essay if available, otherwise a complex test fixture). Read with `readMarkdown` then write with `writeMarkdown`; the second pass should be idempotent or close to it.

### When to stop and ask

If macro expansion fails (`\xx{42}` does not become `X42X`), the prune broke `applyMacros`. Revert with `git reset --hard pre-latex-prune` and ask the user before proceeding.

If raw-tex passthrough fails (the `\textbf{bold}` becomes empty or errors), the prune broke `rawLaTeXInline`. Same — revert and ask.

If the build fails with errors that don't have an obvious fix from the compiler messages, ask before guessing.

### Commit

```
git add -A
git commit -m "Phase 7: prune LaTeX reader to macros + raw passthrough

Deleted Citation.hs, Inline.hs, Lang.hs, SIunitx.hs, Table.hs from
Readers/LaTeX/. Slimmed LaTeX.hs from 1423 to ~350 LOC, exporting
only applyMacros, rawLaTeXBlock, rawLaTeXInline. Math.hs and
Parsing.hs and Macro.hs retained. Macro expansion and raw-tex
passthrough verified working."
```

---

## Phase 8 — API surface verification

### Goal
Confirm the fork exposes the exact symbols Hakyll and Gwern's build need. This is the gate before declaring the fork done.

### Steps

1. Create a verification module that imports every symbol on the API checklist (P0.4):

```bash
mkdir -p verify
cat > verify/ApiSurface.hs <<'EOF'
{-# LANGUAGE OverloadedStrings #-}
-- Imports every Text.Pandoc symbol that Hakyll and gwern.net's
-- build/ directory rely on. If this compiles, the fork is API-compatible
-- with downstream consumers.
module ApiSurface where

import Text.Pandoc
  ( runPure, def
  , Pandoc(..), Block(..), Inline(..), Format(..)
  , nullMeta, nullAttr, MathType(..)
  , ReaderOptions, WriterOptions
  , readerExtensions, writerExtensions, writerColumns
  , writerSectionDivs, writerTableOfContents
  , writerHTMLMathMethod, writerHighlightMethod
  , HTMLMathMethod(..), defaultMathJaxURL
  , WrapPreserve
  , readMarkdown, readHtml
  , writeMarkdown, writeHtml5String
  , pandocExtensions, enableExtension, disableExtension
  , Extension(..)
  )
import Text.Pandoc.Walk (walk, walkM, query, queryWith)
import Text.Pandoc.Builder (setMeta, Blocks, Inlines)
import Text.Pandoc.Class (PandocMonad)
import Text.Pandoc.Highlighting (pygments)
import Text.Pandoc.Writers.Markdown (writePlain)
import Text.Pandoc.Generic (topDown, bottomUp, bottomUpM)

-- Ensure all imports are referenced so unused-import warnings surface
-- any missing exports rather than passing silently.
_apiCheck :: ()
_apiCheck =
  let _ = (runPure, def, nullMeta, nullAttr, defaultMathJaxURL)
      _ = (readMarkdown, readHtml, writeMarkdown, writeHtml5String, writePlain)
      _ = (walk, walkM, query, queryWith, topDown, bottomUp, bottomUpM)
      _ = (pandocExtensions, enableExtension, disableExtension, setMeta)
      _ = (pygments, MathJax, KaTeX, MathML, PlainMath, WrapPreserve)
      _ = (Pandoc, Block, Inline, Format, MathType, Blocks, Inlines)
      _ = (readerExtensions, writerExtensions, writerColumns,
           writerSectionDivs, writerTableOfContents,
           writerHTMLMathMethod, writerHighlightMethod)
  in ()
EOF
```

Compile it standalone against the fork:

```bash
cabal exec ghc -- -fno-code verify/ApiSurface.hs
```

Expected: clean compile, possibly with unused-binding warnings (those are fine — the goal is "do all these imports resolve").

If any import fails to resolve, that symbol is missing from the fork and must be re-exported. Common fixes:
- A symbol that was re-exported from `Text.Pandoc` via a deleted module: add it to `Text.Pandoc`'s explicit export list.
- A symbol whose origin module was deleted: re-export from a sibling module.

2. Roundtrip test:
```bash
cat > verify/Roundtrip.hs <<'EOF'
{-# LANGUAGE OverloadedStrings #-}
import Text.Pandoc
import Text.Pandoc.Walk (walk)
import qualified Data.Text.IO as T
import qualified Data.Text as Text

sampleMarkdown :: Text.Text
sampleMarkdown = Text.unlines
  [ "# Test Doc"
  , ""
  , "Paragraph with *emphasis*, **strong**, and `code`."
  , ""
  , "[Link](https://example.com) and an image: ![alt](img.png)."
  , ""
  , "> Blockquote"
  , ">"
  , "> with multiple paragraphs."
  , ""
  , "- bullet 1"
  , "- bullet 2"
  , ""
  , "1. ordered"
  , "2. items"
  , ""
  , "| Col1 | Col2 |"
  , "|------|------|"
  , "| a    | b    |"
  , ""
  , "Math: $x^2 + y^2 = z^2$ and display:"
  , ""
  , "$$\\int_0^\\infty e^{-x} dx = 1$$"
  , ""
  , "```haskell"
  , "main = putStrLn \"hello\""
  , "```"
  , ""
  , "Footnote[^1]."
  , ""
  , "[^1]: footnote text"
  , ""
  , "\\newcommand{\\xx}[1]{X#1X}"
  , "Macro: $\\xx{42}$."
  ]

main :: IO ()
main = do
  result <- runIO $ do
    p <- readMarkdown def{readerExtensions = pandocExtensions} sampleMarkdown
    -- Verify walk works
    let p' = walk (id :: Inline -> Inline) p
    html <- writeHtml5String
              def{ writerHTMLMathMethod = MathJax defaultMathJaxURL
                 , writerExtensions = pandocExtensions
                 } p'
    md <- writeMarkdown
            def{ writerExtensions = pandocExtensions
               , writerColumns = 9999
               } p'
    plain <- writePlain
               def{writerColumns = 9999} p'
    return (html, md, plain)
  case result of
    Left e -> error (show e)
    Right (html, md, plain) -> do
      putStrLn "=== HTML ==="
      T.putStrLn html
      putStrLn "=== Markdown ==="
      T.putStrLn md
      putStrLn "=== Plain ==="
      T.putStrLn plain
EOF
cabal exec runghc -- verify/Roundtrip.hs
```

Expected output: all three formats produced without errors. The HTML should contain `\(x^2 + y^2 = z^2\)` (MathJax delimiters), `X42X` for the expanded macro, syntax-highlighted Haskell code block, and a footnote section. The Markdown roundtrip should preserve the structure. The Plain output should be the document with formatting stripped.

If any of the three outputs error or are empty, identify which writer/path is broken.

3. Hakyll-compat test (optional but recommended): clone Hakyll and try to build it against the fork:

```bash
cd /tmp
git clone --depth 1 https://github.com/jaspervdj/hakyll.git
cd hakyll
# Pin Hakyll to use the local lean pandoc:
echo "packages: . ../path-to-pandoc-lean" > cabal.project.local
cabal build hakyll 2>&1 | tail -40
```

This will fail because Hakyll's `Web/Pandoc.hs` references `readDocBook`, `readIpynb`, etc. That's expected — the Hakyll fork (separate work item) addresses this. The point of this test is to enumerate exactly which symbols Hakyll references that the fork no longer provides. Save the error log; it will be the spec for the Hakyll fork.

### Commit

```
git add -A
git commit -m "Phase 8: API surface verification

Added verify/ApiSurface.hs and verify/Roundtrip.hs.
All Hakyll/Gwern API symbols resolve. Roundtrip test
confirms readMarkdown -> walk -> writeHtml5String/
writeMarkdown/writePlain pipeline works end-to-end."
```

---

## Phase 9 — Optional aggressive trims

These are independent of each other; do any, all, or none. Each one in its own commit.

### P9.1 — Drop Class/Sandbox

`src/Text/Pandoc/Class/Sandbox.hs` (~61 LOC) is for sandboxed Lua execution. Lua is gone, so the sandbox is unreachable.

```
git rm src/Text/Pandoc/Class/Sandbox.hs
# Remove from pandoc.cabal exposed-modules / other-modules
# Search for importers and remove imports:
grep -rln 'Text.Pandoc.Class.Sandbox' src/
```

### P9.2 — Drop Class/IO/HTTP

`src/Text/Pandoc/Class/IO/HTTP.hs` (~115 LOC) is for fetching URLs at conversion time (used by `--self-contained` for inlining remote images). Drop only if you also drop `SelfContained.hs`. If Gwern uses self-contained HTML for any page, do not drop.

### P9.3 — Strip Logging

`src/Text/Pandoc/Logging.hs` (~505 LOC) defines a large `LogMessage` ADT, many of whose constructors reference deleted formats (`CouldNotFetchResource`, `DocxDocxParseError`, etc., depending on what was there). Trim by deleting unused constructors and following the compile errors. Save: ~200 LOC.

### P9.4 — Drop SelfContained

`src/Text/Pandoc/SelfContained.hs` (~200 LOC) inlines images/scripts/CSS into HTML. Drop if Gwern's pipeline doesn't use the `--self-contained` / `embed-resources` extension.

### P9.5 — Drop other unused modules

Run:
```bash
grep -rln 'import Text.Pandoc' src/ | sort -u
```
Cross-reference with what gets imported transitively from `readMarkdown`, `readHtml`, `writeMarkdown`, `writeHtml5String`, `writePlain`. Anything not on the chain is droppable. Candidates likely include `Text.Pandoc.Process`, `Text.Pandoc.Image`, `Text.Pandoc.Format` (verify each).

After P9, target is ~22,000 LOC in `src/`.

---

## Phase 10 — Documentation and final state

### Steps

1. Update `README.md` with a fork notice at the top:
   ```markdown
   # Pandoc (lean fork)

   This is a stripped-down fork of [pandoc](https://github.com/jgm/pandoc)
   maintained for use with Hakyll-based static site builds. It supports:

   - Pandoc Markdown reader (full classical extension set, including +latex_macros)
   - HTML reader
   - HTML5 writer
   - Markdown writer (and writePlain)
   - JSON filters via Text.Pandoc.Filter

   It does **not** support: Lua filters, citeproc, or any reader/writer
   other than those listed above (DOCX, EPUB, LaTeX-output, etc. all removed).

   Forked from upstream commit <hash>, <date>.

   For the full-featured pandoc, see https://github.com/jgm/pandoc.
   ```

2. Update `pandoc.cabal`:
   - Change `name:` to `pandoc-lean` (or keep `pandoc` if you want drop-in compat — the latter requires careful version pinning by downstream)
   - Bump version to indicate fork (e.g., `3.9.0.2-lean.1`)
   - Update `synopsis` and `description`
   - Update `homepage` and `bug-reports` to your fork's URL

3. Add `MAINTENANCE.md` documenting the fork strategy (taken from your conversation):
   ```markdown
   # Maintenance Strategy

   Hard fork. Upstream pandoc is not tracked automatically.

   ## Pulling upstream changes

   When a relevant upstream change occurs (security fix, Markdown reader bug,
   HTML writer regression):

   1. `git remote add upstream https://github.com/jgm/pandoc.git`
   2. `git fetch upstream`
   3. Identify the commits affecting kept files:
      `git log upstream/master -- src/Text/Pandoc/Readers/Markdown.hs src/Text/Pandoc/Writers/HTML.hs ...`
   4. Cherry-pick selectively. Conflicts in deleted files don't apply.

   ## Files that frequently see upstream changes (high-attention)

   - src/Text/Pandoc/Readers/Markdown.hs
   - src/Text/Pandoc/Writers/HTML.hs
   - src/Text/Pandoc/Writers/Markdown.hs
   - src/Text/Pandoc/Extensions.hs
   - src/Text/Pandoc/Options.hs
   - pandoc-types (vendored separately)

   ## Files that rarely change (low-attention)

   - Class/* hierarchy (PandocMonad)
   - Parsing infrastructure
   - LaTeX reader (we trimmed it; upstream changes here are rare and
     usually orthogonal to the macro/raw subset we kept)
   ```

4. Run final measurements and update `FORK.md`:
   ```bash
   cloc src/ | tee -a FORK.md
   ```
   Add a "Final state" section comparing pre-fork and post-fork LOC.

### Final commit

```
git add -A
git commit -m "Phase 10: documentation and fork branding

Updated README, cabal package name/version, added MAINTENANCE.md.
Final size: ~27K LOC src/ (from ~80K). Build time approximately
halved from upstream baseline."
git tag lean-fork-1.0
```

---

## Sanity targets at end of all phases

| Metric | Upstream | Target after Phase 7 | Target after Phase 9 |
|---|---|---|---|
| `cloc src/` Haskell LOC | ~80,000 | ~27,000 | ~22,000 |
| Modules in `exposed-modules` | ~140 | ~50 | ~40 |
| `build-depends` count | ~50 | ~30 | ~25 |
| Cold `cabal build` time | (record P0.2 baseline) | 50% of baseline | 40% of baseline |
| Roundtrip test (Phase 8 #2) | passes | passes | passes |

If your numbers diverge significantly from these (more than 25% off in either direction), stop and report — something is off.

---

## When to stop and ask the user

- Any phase's verification step fails in a way you can't trace to the obvious cause from compiler errors
- Phase 7's macro test produces wrong output (macro not expanded, or wrong expansion)
- The API surface check (Phase 8) finds a missing symbol you don't know how to re-export
- LOC numbers are dramatically different from the targets table (suggesting modules were deleted or kept incorrectly)
- You encounter a module import you don't recognize and aren't sure whether to keep
- You're tempted to refactor or "improve" code beyond the deletions specified — don't; this is a deletion exercise, not a rewrite

## When to proceed without asking

- Compiler warnings about unused imports/bindings (clean up at end of phase)
- Test files that fail because they reference deleted readers/writers (delete them)
- Cabal warnings about version bounds (leave as-is unless the build actually fails)
- Whitespace, trailing-newline, or encoding inconsistencies in retained files (leave alone)

## Working style

- Commit after each phase. The commits in this manual are not optional; they form the audit trail and the rollback points.
- After each phase verification, run `cloc src/` and record the count in your phase commit message. This makes drift visible.
- Keep `FORK.md` updated with running totals.
- When in doubt about whether a module is needed, search for its identifier in `Markdown.hs`, `HTML.hs`, `Writers/HTML.hs`, `Writers/Markdown.hs`, `Filter.hs`, `Filter/JSON.hs`. If none of these reference it (directly or transitively via a kept module), it's deletable.

## Anti-goals (do not do)

- Do not modernize or refactor the kept code. The Markdown reader and HTML writer are battle-tested; behavioral preservation matters more than code style.
- Do not "fix" things you notice in passing. File issues if they're real, but don't expand scope.
- Do not delete `pandoc-types` upstream — it's a separate package this fork depends on as a Hackage library. Vendoring it is a Phase 11 decision the user has not yet authorized.
- Do not delete `texmath` or `skylighting`. They were considered for removal but the user explicitly chose to defer those decisions.
- Do not change the public types in `Text.Pandoc.Definition` (Block, Inline, Pandoc, etc.). Those live in `pandoc-types` anyway, but if you find yourself touching them, stop.
