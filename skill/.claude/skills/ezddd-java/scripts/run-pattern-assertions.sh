#!/usr/bin/env bash
# run-pattern-assertions.sh — Wrapper (v3.0)
#
# Pattern assertions (FC-C, FC-D, FC-E) are now integrated into
# check-pattern-consistency.sh Phase 3 (Canonical Pattern Existence).
# This wrapper preserves backward compatibility.
#
# Usage:
#   .claude/skills/ezddd-java/scripts/run-pattern-assertions.sh
#
# Exit codes: Delegates to check-pattern-consistency.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "NOTE: Assertions are now part of check-pattern-consistency.sh Phase 3."
echo "Running full consistency check..."
echo ""

exec "$SCRIPT_DIR/check-pattern-consistency.sh" "$@"
