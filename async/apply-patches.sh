#!/bin/sh
# Applies the php-src patches this branch needs to a prepared php-src tree.
#
#   async/apply-patches.sh /path/to/php-src
#
# Branch async only. Main carries no php-src patch (issues #589-#592): its
# vendored tree is pristine and its build never touches the engine. The
# fiber executor does need two changes inside php-src (0007 TLS transports,
# 0008 stream_select), both inert unless HAVE_FPMNG_FIBER is defined, so they
# live here and are applied only by the from-source fiber build
# (async/build-tree.sh). Why each exists: async/README.md.
#
# Idempotent: a patch the tree already carries is reported, not applied twice.
set -eu

PHPSRC="${1:?usage: async/apply-patches.sh <php-src-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -f "$PHPSRC/main/php_version.h" ] || { echo "apply-patches: $PHPSRC does not look like php-src" >&2; exit 1; }

n=0
for p in "$HERE"/patches/*.patch; do
  name=$(basename "$p")
  # Forward dry run first: a patch that applies cleanly is applied. Only when
  # it does not, ask whether it is already there (reverse dry run). Order
  # matters on BSD patch, where a forward dry run on an applied patch can
  # succeed (the same trap build/prepare.sh's old patch step documented).
  if patch -d "$PHPSRC" -p1 --dry-run --forward --silent < "$p" >/dev/null 2>&1; then
    patch -d "$PHPSRC" -p1 --forward --silent < "$p" >/dev/null ||
      { echo "apply-patches: $name failed halfway; discard $PHPSRC" >&2; exit 1; }
    echo "apply-patches: applied $name"
  elif patch -d "$PHPSRC" -p1 --dry-run --reverse --silent < "$p" >/dev/null 2>&1; then
    echo "apply-patches: $name was already applied"
  else
    echo "apply-patches: $name does not apply to $(sed -n 's/^#define PHP_VERSION "\(.*\)"/\1/p' "$PHPSRC/main/php_version.h")" >&2
    echo "  upstream may have merged or moved it; see async/README.md" >&2
    exit 1
  fi
  n=$((n + 1))
done
[ "$n" -gt 0 ] || { echo "apply-patches: no patches found in $HERE/patches" >&2; exit 1; }
