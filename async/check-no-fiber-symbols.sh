#!/bin/sh
# Fails when a php-fpm-ng binary carries fiber/coop/async executor code.
#
#   async/check-no-fiber-symbols.sh <binary>
#
# Branch async only. The default (SDK) build must be main's binary plus
# nothing: the executors are compiled out because a distribution libphp cannot
# carry patches 0007/0008. build/libphp-build.sh calls this on its own output,
# so every pull request into async runs it through main's pipeline.
#
# Symbol names come from the executors' own prefixes. A binary that was
# stripped has no symbol table to read, and an empty answer would then pass for
# the wrong reason, so the script refuses a binary it cannot read symbols from.
set -eu

BIN="${1:?usage: async/check-no-fiber-symbols.sh <binary>}"
[ -f "$BIN" ] || { echo "check-no-fiber-symbols: no such file: $BIN" >&2; exit 2; }
command -v nm >/dev/null 2>&1 || { echo "check-no-fiber-symbols: nm is not installed (binutils)" >&2; exit 2; }

SYMS=$(nm "$BIN" 2>/dev/null || true)
# Control: a symbol every build has. Without it the next check could pass on an
# unreadable (stripped) binary.
echo "$SYMS" | grep -qE ' [TtDdBb] fpm_pool_type_get$' ||
  { echo "check-no-fiber-symbols: $BIN has no readable symbol table (stripped?)" >&2; exit 2; }

# fpm_pool_type_coop_variant() is the always-built lookup (fpm_pool_type_coop.c)
# and is deliberately not matched: its prefix is fpm_pool_type_.
HITS=$(echo "$SYMS" | grep -E ' [A-Za-z] (fpm_pool_(fiber|coop|async)_|fpm_(fiber|coop|async)_)' || true)
if [ -n "$HITS" ]; then
  echo "check-no-fiber-symbols: FAIL: $BIN carries executor symbols:" >&2
  echo "$HITS" | head -20 >&2
  exit 1
fi
echo "check-no-fiber-symbols: ok, no fiber/coop/async symbols in $BIN"
