#!/usr/bin/env bash
# Smoke-tests for the gwark CLI's Lua filter support.
#
# Runs the gwark binary built by `cabal build all` against a few
# small Lua filters and checks the output. Exits non-zero if any
# check fails.
#
# Usage:
#   verify/lua/run-tests.sh
#
# Looks up the gwark binary via `cabal list-bin gwark`. Requires
# `cabal` and a built `gwark` executable.

set -euo pipefail

cd "$(dirname "$0")/../.."

# Take only the last non-empty line of stdout. cabal can chatter
# above the path on the first invocation after a `cabal update`.
GWARK="$(cabal list-bin gwark-cli:exe:gwark 2>/dev/null | awk 'NF{p=$0} END{print p}')"
if [ ! -x "$GWARK" ]; then
  echo "gwark executable not found at: $GWARK" >&2
  echo "Run 'cabal build all' first." >&2
  exit 2
fi

pass=0
fail=0

check () {
  local name=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    echo "ok   $name"
    pass=$((pass + 1))
  else
    echo "FAIL $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    fail=$((fail + 1))
  fi
}

# 1. uppercase.lua: Str -> uppercase.
got=$(printf '%s\n' 'hello world' \
  | "$GWARK" -f markdown -t plain --lua-filter=verify/lua/uppercase.lua \
  | tr -d '\n')
check "uppercase.lua transforms 'hello world' -> 'HELLO WORLD'" \
      "HELLO WORLD" "$got"

# 2. wrap-emph.lua: Str -> Emph(Str). Emit native AST so we can
#    grep the structure unambiguously.
got=$("$GWARK" -f markdown -t native --lua-filter=verify/lua/wrap-emph.lua \
       <<< 'foo bar' \
       | tr -d '\n ')
case "$got" in
  *"Emph[Str\"foo\"]"*"Emph[Str\"bar\"]"*)
    echo "ok   wrap-emph.lua wraps each Str in Emph"
    pass=$((pass + 1))
    ;;
  *)
    echo "FAIL wrap-emph.lua wraps each Str in Emph"
    echo "  actual: $got"
    fail=$((fail + 1))
    ;;
esac

# 3. wrap-emph.lua also adds a Meta entry. Ask for HTML5 with
#    --standalone so the metadata appears in the output.
got=$("$GWARK" -f markdown -t markdown --standalone \
       --lua-filter=verify/lua/wrap-emph.lua <<< 'x' \
       | grep -c '^wrap-emph: true$' || true)
check "wrap-emph.lua sets meta wrap-emph=true" "1" "$got"

# 4. Two filters chained: uppercase then wrap-emph.
got=$("$GWARK" -f markdown -t native \
       --lua-filter=verify/lua/uppercase.lua \
       --lua-filter=verify/lua/wrap-emph.lua \
       <<< 'hi' \
       | tr -d '\n ')
case "$got" in
  *"Emph[Str\"HI\"]"*)
    echo "ok   uppercase + wrap-emph chain produces Emph[Str \"HI\"]"
    pass=$((pass + 1))
    ;;
  *)
    echo "FAIL uppercase + wrap-emph chain"
    echo "  actual: $got"
    fail=$((fail + 1))
    ;;
esac

# 5. --version reports +lua.
if "$GWARK" --version | head -2 | grep -q '+lua'; then
  echo "ok   --version reports +lua"
  pass=$((pass + 1))
else
  echo "FAIL --version reports +lua"
  fail=$((fail + 1))
fi

echo
echo "$pass passed, $fail failed"
exit "$fail"
