# Building gwark from source on Ubuntu

These steps were verified on **Ubuntu 24.04 LTS (noble)** with
**GHC 9.6.6** and **cabal-install 3.10.3.0**, building from a clean
`git clean -fdx` working tree.

## 1. Install system packages

`apt` covers the C toolchain and the libraries that GHC and Haskell
deps link against (GMP for the bignum runtime, zlib for `zlib`,
`zip-archive`, etc.). `cloc` is optional — it is only used by
`FORK.md` accounting.

```
sudo apt update
sudo apt install -y build-essential curl libgmp-dev zlib1g-dev pkg-config
sudo apt install -y cloc                # optional
```

## 2. Install GHC and cabal via ghcup

Ubuntu's `ghc` package lags behind. Use [ghcup](https://www.haskell.org/ghcup/)
to get the exact versions this fork is tested against:

```
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org \
  | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1 \
    BOOTSTRAP_HASKELL_INSTALL_HLS=0 \
    BOOTSTRAP_HASKELL_GHC_VERSION=9.6.6 \
    BOOTSTRAP_HASKELL_CABAL_VERSION=3.10.3.0 \
    BOOTSTRAP_HASKELL_NO_UPGRADE=1 \
    sh

# Make ghcup binaries available in this shell.
export PATH="$HOME/.ghcup/bin:$PATH"
```

For subsequent shells, source `~/.ghcup/env` (ghcup writes a small
script at install time) or add the `export PATH=...` line to
`~/.bashrc`.

Verify:

```
ghc --version          # The Glorious Glasgow Haskell Compilation System, version 9.6.6
cabal --version        # cabal-install version 3.10.3.0
```

Newer GHCs (9.8.x, 9.10.x) probably also work — `gwark.cabal` advertises
`tested-with: GHC == 9.6.7, GHC == 9.8.4, GHC == 9.10.3, GHC == 9.12.2` —
but the only compiler the fork has been smoke-tested on is 9.6.6.

## 3. Clone and build

```
git clone https://github.com/dbohdan/pandoc.git gwark
cd gwark
git checkout claude/trim-pandoc-gwern-7jEEj   # until the branch is merged
cabal update
cabal build all
```

Expected build artefacts:

- The `gwark` library: `dist-newstyle/build/<arch>/ghc-9.6.6/gwark-3.9.0.2/build/libHSgwark-*.a`
- The `gwark` executable: `dist-newstyle/build/<arch>/ghc-9.6.6/gwark-cli-3.9.0.2/x/gwark/build/gwark/gwark`

Exact path is reported by `cabal list-bin gwark`.

## 4. Smoke test

```
cabal exec gwark -- --version
# gwark 3.9.0.2
# Features: -server -lua
# Scripting engine: none

echo '# Hello' | cabal exec gwark -- -f markdown -t html5
# <h1 id="hello">Hello</h1>
```

The English-translation warning that prints on every conversion
(`data file translations/en.yaml not found`) is harmless: the lean
fork drops `data/translations/`, but the translation lookup is still
attempted. It does not affect output.

## 5. Install (optional)

```
cabal install gwark-cli
# binary is copied to ~/.cabal/bin/gwark
```

Ensure `~/.cabal/bin` is on your `PATH`.

## 6. Build from a completely clean tree (regression check)

```
git clean -fdx                  # also removes dist-newstyle/, cabal caches
cabal update
cabal build all
```

This was the exact procedure used to verify the build before this
file was written. If `cabal update` skips because the cache is present
under `~/.cabal/`, that is fine — the build does not depend on a
specific Hackage index.

## Build times

On a modern x86_64 Linux box (16 GB RAM, 8 cores), a from-scratch
`cabal build all` completes in **3–6 minutes** of wall time after
`cabal update`. That includes compiling all transitive Haskell
dependencies the first time. Incremental rebuilds after a single-file
edit are typically under 10 seconds.

## Troubleshooting

- **`cannot find -lgmp`**: install `libgmp-dev` (step 1).
- **`Could not find module 'Paths_pandoc'`**: you have the upstream
  pandoc source tree, not gwark. The fork's autogen module is
  `Paths_gwark`.
- **`texmath` build failure mentioning `TS.Sym` / `TS.symText`**:
  `cabal.project` should pin `texmath == 0.13.0.1` and
  `typst-symbols >= 0.1.8.1 && < 0.1.9`. Newer texmath HEAD requires
  a typst-symbols dev API not on Hackage. Re-`cabal update` and
  rebuild; if you have a stale `cabal.project.local` from upstream,
  delete it.
- **A reader/writer is missing**: this is intentional. See the README
  for the supported set (Markdown / HTML in, HTML / Markdown / plain /
  Markua out). For everything else, use upstream pandoc.
