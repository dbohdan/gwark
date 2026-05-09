Forked from pandoc upstream commit 12051ec38a433fbea481f7701f1667caf17d0c9b (release 3.9.0.2 head of `main` as of fork start), 2026-05-09.

## Baseline

Pre-fork measurements taken from the upstream tree before any deletions:

```
cloc src/ pandoc-cli/src/ pandoc-server/src/ pandoc-lua-engine/src/
Haskell:  281 files,  8990 blank,  9699 comment,  84637 code
```

(`citeproc/` in this tree is a data directory of `biblatex-localization` strings; the citeproc Haskell package is pulled from Hackage.)

Cold `cabal build` time: not recorded — Haskell toolchain was being installed when the fork began. The post-fork build time will stand on its own.

## Phase log

(Updated at the end of each phase.)
