#!/bin/sh
# Hands back a configured php-src tree for the from-source FIBER build: a fresh
# checkout of php-src, async/prepare.sh, buildconf, configure.
#
#   async/build-tree.sh <tree-dir> <php-src-repo> <php-src-ref> <configure flags...>
#
# Branch async only. It replaces build/ci-build-tree.sh, which main deleted
# together with the php-src build as the supported path (#419, #422). There is
# no reuse key: the one consumer is a hosted runner that starts empty, and the
# compile is what ccache covers. The tree is always rebuilt from scratch, so a
# stale object list cannot survive a changed source list.
#
# The configure log is kept INSIDE the tree (<tree>/.fpmng-ci-configure.log)
# and the workflow asserts on it: configure warns, it does not fail, on an
# unknown --enable flag, so the command line proves nothing.
set -eu

TREE="${1:?usage: async/build-tree.sh <tree-dir> <php-src-repo> <php-src-ref> <configure flags...>}"
SRC_REPO="${2:?provide the php-src repository URL}"
SRC_REF="${3:?provide the php-src ref}"
shift 3

REPO="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf "$TREE"
mkdir -p "$TREE"
git init -q "$TREE"
git -C "$TREE" fetch -q --depth 1 "$SRC_REPO" "$SRC_REF"
git -C "$TREE" checkout -q FETCH_HEAD

"$REPO/async/prepare.sh" "$TREE"

LOG="$TREE/.fpmng-ci-configure.log"
if ! ( cd "$TREE" && ./buildconf --force ) > "$TREE/.fpmng-ci-buildconf.log" 2>&1; then
  echo "=== BUILDCONF FAILED ==="
  tail -20 "$TREE/.fpmng-ci-buildconf.log"
  exit 1
fi
if ! ( cd "$TREE" && ./configure "$@" ) > "$LOG" 2>&1; then
  echo "=== CONFIGURE FAILED ==="
  tail -20 "$LOG"
  exit 1
fi
echo "async/build-tree.sh: tree $TREE, configure log $LOG"
