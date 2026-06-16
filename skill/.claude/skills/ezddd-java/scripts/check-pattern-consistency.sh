#!/usr/bin/env bash
# check-pattern-consistency.sh
#
# Data-driven pattern consistency checker for ezddd-java skill.
# Reads AUTHORITY-REGISTRY.yaml and validates:
#   1. Anti-pattern checks: consumer files don't contain anti-patterns marked as correct
#   2. @authority marker checks: consumer files have proper @authority markers
#   3. Canonical pattern existence: consumer files contain the canonical pattern
#   4. Authority file existence: all authority files referenced in registry exist
#   5. Line hint drift detection: authority_line_hint still points to relevant content
#   6. Multi-line pattern checks: validates patterns containing \n using perl multi-line matching
#
# Usage:
#   .claude/skills/ezddd-java/scripts/check-pattern-consistency.sh
#
# Exit codes:
#   0 = all checks passed
#   1 = contradictions or critical violations found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REFS_DIR="$SKILL_DIR/references"
REGISTRY="$REFS_DIR/AUTHORITY-REGISTRY.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0
TOPIC_COUNT=0

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║    Pattern Consistency Check v3.2 — ezddd-java skill         ║"
echo "║    Data-driven from AUTHORITY-REGISTRY.yaml (6 phases)       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [[ ! -f "$REGISTRY" ]]; then
    echo -e "${RED}ERROR: AUTHORITY-REGISTRY.yaml not found at $REGISTRY${NC}"
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Lightweight YAML parser for our fixed registry structure
# Extracts topic_id, anti_pattern, consumer files, and severity
# ─────────────────────────────────────────────────────────────

# Parse all topic IDs from the registry
get_topics() {
    # Match lines that are direct children of 'topics:' (2-space indented, ending with ':')
    awk '
    /^topics:/ { in_topics=1; next }
    in_topics && /^  [a-z]/ && !/^    / {
        line=$0; sub(/:.*/, "", line); gsub(/ /, "", line)
        if (line ~ /^[a-z_]+$/) print line
    }
    ' "$REGISTRY"
}

# Get a scalar field value for a topic
get_field() {
    local topic="$1"
    local field="$2"
    awk -v topic="$topic" -v field="$field" '
    /^  '"$topic"':$/ { found=1; next }
    found && /^  [a-z_]+:$/ { found=0 }
    found && /^    '"$field"':/ {
        val = $0
        sub(/^    '"$field"': */, "", val)
        gsub(/^["'"'"']|["'"'"']$/, "", val)
        print val
        exit
    }
    ' "$REGISTRY"
}

# Get consumer file paths (from consumers: and template_consumers:)
get_consumer_files() {
    local topic="$1"
    awk -v topic="$topic" '
    /^  '"$topic"':$/ { found=1; next }
    found && /^  [a-z_]+:$/ { found=0 }
    found && /^    (consumers|template_consumers|jit_consumers):/ { in_list=1; next }
    found && in_list && /^      - file:/ {
        val = $0
        sub(/^      - file: */, "", val)
        gsub(/["'"'"']/, "", val)
        print val
    }
    found && in_list && /^    [a-z]/ && !/^      / { in_list=0 }
    ' "$REGISTRY"
}

# Parse rule_consumers list from meta section
# Returns one file path per line (files classified as "rule" type)
get_rule_consumers() {
    awk '
    /^  rule_consumers:/ { in_list=1; next }
    in_list && /^    - / {
        val = $0
        sub(/^    - */, "", val)
        gsub(/["'"'"']/, "", val)
        print val
        next
    }
    in_list && /^  [a-z]/ { in_list=0 }
    ' "$REGISTRY"
}

# Check if a consumer file path is a "rule" type consumer
# Args: $1 = consumer file relative path
# Returns: 0 if rule, 1 if reference (default)
is_rule_consumer() {
    local cf="$1"
    echo "$RULE_CONSUMERS" | grep -qxF "$cf"
}

# Pre-load rule consumers list (avoid repeated parsing)
RULE_CONSUMERS=$(get_rule_consumers)

# ─────────────────────────────────────────────────────────────
# PHASE 1: Anti-pattern checks (original logic, now data-driven)
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══ PHASE 1: Anti-Pattern Contradiction Checks ═══${NC}"
echo ""

P1_SKIP=0
topics=$(get_topics)

for topic in $topics; do
    anti_pattern=$(get_field "$topic" "anti_pattern")
    severity=$(get_field "$topic" "severity")
    description=$(get_field "$topic" "description")

    # Skip topics without anti_pattern that can be grepped
    if [[ -z "$anti_pattern" ]] || [[ "$anti_pattern" == *$'\n'* ]]; then
        continue
    fi

    # Skip multi-line regex patterns (not suitable for grep)
    if [[ "$anti_pattern" == *'\n'* ]]; then
        continue
    fi

    TOPIC_COUNT=$((TOPIC_COUNT + 1))
    severity_upper=$(echo "$severity" | tr '[:lower:]' '[:upper:]')
    echo -e "${CYAN}[${severity_upper}] ${topic}${NC}"
    echo "  $description"

    consumer_files=$(get_consumer_files "$topic")

    if [[ -z "$consumer_files" ]]; then
        echo -e "  ${YELLOW}SKIP${NC} No consumer files defined"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        echo ""
        continue
    fi

    topic_has_fail=0

    while IFS= read -r cf; do
        [[ -z "$cf" ]] && continue
        filepath="$REFS_DIR/$cf"

        if [[ ! -f "$filepath" ]]; then
            echo -e "  ${YELLOW}SKIP${NC} $cf (file not found)"
            SKIP_COUNT=$((SKIP_COUNT + 1))
            continue
        fi

        # Rule consumers: descriptive references to anti-patterns are expected → SKIP
        if is_rule_consumer "$cf"; then
            echo -e "  ${YELLOW}SKIP${NC} $cf (rule consumer)"
            P1_SKIP=$((P1_SKIP + 1))
            continue
        fi

        # Check if anti-pattern exists and is NOT marked as wrong
        if grep -En "$anti_pattern" "$filepath" 2>/dev/null | grep -v '❌\|WRONG\|deprecated\|WRONG!' | grep -q '.'; then
            echo -e "  ${RED}FAIL${NC} $cf — anti-pattern found"
            grep -En "$anti_pattern" "$filepath" 2>/dev/null | grep -v '❌\|WRONG\|deprecated' | head -2 | while IFS= read -r line; do
                echo "        $line"
            done
            FAIL_COUNT=$((FAIL_COUNT + 1))
            topic_has_fail=1
        else
            echo -e "  ${GREEN}PASS${NC} $cf"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
    done <<< "$consumer_files"

    echo ""
done

# ─────────────────────────────────────────────────────────────
# PHASE 2: @authority marker verification
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══ PHASE 2: @authority Marker Verification ═══${NC}"
echo ""

MARKER_PASS=0
MARKER_WARN=0

for topic in $topics; do
    consumer_files=$(get_consumer_files "$topic")

    [[ -z "$consumer_files" ]] && continue

    while IFS= read -r cf; do
        [[ -z "$cf" ]] && continue
        filepath="$REFS_DIR/$cf"

        if [[ ! -f "$filepath" ]]; then
            continue
        fi

        if grep -q "@authority: $topic" "$filepath"; then
            MARKER_PASS=$((MARKER_PASS + 1))
        else
            echo -e "  ${YELLOW}WARN${NC} Missing @authority: $topic in $cf"
            MARKER_WARN=$((MARKER_WARN + 1))
        fi
    done <<< "$consumer_files"
done

echo ""
echo -e "  Markers found: ${GREEN}${MARKER_PASS}${NC}  Missing: ${YELLOW}${MARKER_WARN}${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 3: Canonical Pattern Existence (NEW in v3.0)
# Verifies that consumer files contain the canonical_pattern
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══ PHASE 3: Canonical Pattern Existence Checks ═══${NC}"
echo ""

P3_PASS=0
P3_FAIL=0
P3_SKIP=0

for topic in $topics; do
    canonical_pattern=$(get_field "$topic" "canonical_pattern")
    severity=$(get_field "$topic" "severity")
    description=$(get_field "$topic" "description")

    # Skip topics without canonical_pattern
    if [[ -z "$canonical_pattern" ]]; then
        continue
    fi

    # Skip multi-line patterns (contain literal \n)
    if [[ "$canonical_pattern" == *'\n'* ]]; then
        continue
    fi

    consumer_files=$(get_consumer_files "$topic")

    if [[ -z "$consumer_files" ]]; then
        continue
    fi

    severity_upper=$(echo "$severity" | tr '[:lower:]' '[:upper:]')
    echo -e "${CYAN}[${severity_upper}] ${topic}${NC}"
    echo "  canonical: $canonical_pattern"

    while IFS= read -r cf; do
        [[ -z "$cf" ]] && continue
        filepath="$REFS_DIR/$cf"

        if [[ ! -f "$filepath" ]]; then
            echo -e "  ${YELLOW}SKIP${NC} $cf (file not found)"
            P3_SKIP=$((P3_SKIP + 1))
            continue
        fi

        # Rule consumers: canonical code patterns are not expected in prose → SKIP
        if is_rule_consumer "$cf"; then
            echo -e "  ${YELLOW}SKIP${NC} $cf (rule consumer)"
            P3_SKIP=$((P3_SKIP + 1))
            continue
        fi

        if grep -qE "$canonical_pattern" "$filepath" 2>/dev/null; then
            echo -e "  ${GREEN}PASS${NC} $cf"
            P3_PASS=$((P3_PASS + 1))
        else
            if [[ "$severity" == "critical" ]]; then
                echo -e "  ${RED}FAIL${NC} $cf — canonical pattern MISSING"
                P3_FAIL=$((P3_FAIL + 1))
            else
                echo -e "  ${YELLOW}WARN${NC} $cf — canonical pattern missing"
                WARN_COUNT=$((WARN_COUNT + 1))
            fi
        fi
    done <<< "$consumer_files"

    echo ""
done

echo -e "  Phase 3: PASS=${GREEN}${P3_PASS}${NC}  FAIL=${RED}${P3_FAIL}${NC}  SKIP=${YELLOW}${P3_SKIP}${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 4: Authority File Existence (NEW in v3.0)
# Verifies that all referenced authority files actually exist
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══ PHASE 4: Authority File Existence ═══${NC}"
echo ""

P4_PASS=0
P4_FAIL=0
PROJECT_DIR="$(cd "$SKILL_DIR/../.." && pwd)"

for topic in $topics; do
    authority_file=$(get_field "$topic" "authority")

    if [[ -z "$authority_file" ]]; then
        continue
    fi

    # Resolve full path: CLAUDE.md is at project root, others under references/
    if [[ "$authority_file" == "CLAUDE.md" ]]; then
        full_path="$PROJECT_DIR/CLAUDE.md"
    else
        full_path="$REFS_DIR/$authority_file"
    fi

    if [[ -f "$full_path" ]]; then
        P4_PASS=$((P4_PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $topic → authority file NOT FOUND: $authority_file"
        P4_FAIL=$((P4_FAIL + 1))
    fi
done

echo ""
echo -e "  Phase 4: PASS=${GREEN}${P4_PASS}${NC}  FAIL=${RED}${P4_FAIL}${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 5: Line Hint Drift Detection (NEW in v3.0, WARN only)
# Checks if authority_line_hint still points to relevant content
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══ PHASE 5: Line Hint Drift Detection (warn only) ═══${NC}"
echo ""

P5_PASS=0
P5_WARN=0
P5_SKIP=0

for topic in $topics; do
    line_hint=$(get_field "$topic" "authority_line_hint")
    authority_file=$(get_field "$topic" "authority")
    description=$(get_field "$topic" "description")

    # Skip topics without line hint or with null
    if [[ -z "$line_hint" ]] || [[ "$line_hint" == "null" ]]; then
        P5_SKIP=$((P5_SKIP + 1))
        continue
    fi

    # Resolve full path
    if [[ "$authority_file" == "CLAUDE.md" ]]; then
        full_path="$PROJECT_DIR/CLAUDE.md"
    else
        full_path="$REFS_DIR/$authority_file"
    fi

    if [[ ! -f "$full_path" ]]; then
        P5_SKIP=$((P5_SKIP + 1))
        continue
    fi

    # Extract a keyword from description (first significant word after common prefixes)
    keyword=$(echo "$description" | sed 's/^[A-Z][a-z]* //' | awk '{print $1}' | tr -d '",')

    # Read ±5 lines around the hint
    start_line=$((line_hint - 5))
    if [[ $start_line -lt 1 ]]; then start_line=1; fi
    end_line=$((line_hint + 5))

    window=$(sed -n "${start_line},${end_line}p" "$full_path" 2>/dev/null || true)

    if echo "$window" | grep -qi "$keyword" 2>/dev/null; then
        P5_PASS=$((P5_PASS + 1))
    else
        echo -e "  ${YELLOW}WARN${NC} $topic — line hint $line_hint may be stale in $authority_file"
        echo "        keyword: \"$keyword\" not found in lines ${start_line}-${end_line}"
        P5_WARN=$((P5_WARN + 1))
    fi
done

echo ""
echo -e "  Phase 5: PASS=${GREEN}${P5_PASS}${NC}  WARN=${YELLOW}${P5_WARN}${NC}  SKIP=${YELLOW}${P5_SKIP}${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 6: Multi-line Pattern Checks (NEW in v3.1)
# Validates patterns containing \n using perl multi-line matching
# Phases 1+3 skip multi-line patterns; this phase handles them
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══ PHASE 6: Multi-line Pattern Checks (perl -0777) ═══${NC}"
echo ""

P6_PASS=0
P6_FAIL=0
P6_SKIP=0
P6_TOPICS=0

# Helper: extract multi-line topics (patterns containing literal \n)
get_multiline_topics() {
    awk '
    /^topics:/ { in_topics=1; next }
    in_topics && /^  [a-z]/ && !/^    / {
        line=$0; sub(/:.*/, "", line); gsub(/ /, "", line)
        if (line ~ /^[a-z_]+$/) current_topic = line
    }
    in_topics && /^    (canonical_pattern|anti_pattern):/ {
        if (index($0, "\\n") > 0) {
            print current_topic
        }
    }
    ' "$REGISTRY" | sort -u
}

# Check multi-line pattern in a file using perl
# Args: $1=pattern_type (canonical/anti), $2=pattern, $3=filepath, $4=topic, $5=severity
check_multiline_pattern() {
    local ptype="$1"
    local pattern="$2"
    local filepath="$3"
    local topic="$4"
    local severity="$5"

    if [[ ! -f "$filepath" ]]; then
        echo -e "  ${YELLOW}SKIP${NC} $(basename "$filepath") (file not found)"
        P6_SKIP=$((P6_SKIP + 1))
        return
    fi

    # Convert YAML \n to actual regex newline for perl
    local perl_pattern
    perl_pattern=$(echo "$pattern" | sed 's/\\n/\\n/g')

    if perl -0777 -ne "exit(/$perl_pattern/ ? 0 : 1)" "$filepath" 2>/dev/null; then
        if [[ "$ptype" == "canonical" ]]; then
            echo -e "  ${GREEN}PASS${NC} $(basename "$filepath") — canonical multi-line pattern found"
            P6_PASS=$((P6_PASS + 1))
        else
            # anti-pattern found = FAIL
            echo -e "  ${RED}FAIL${NC} $(basename "$filepath") — anti-pattern multi-line match"
            P6_FAIL=$((P6_FAIL + 1))
        fi
    else
        if [[ "$ptype" == "canonical" ]]; then
            if [[ "$severity" == "critical" ]]; then
                echo -e "  ${RED}FAIL${NC} $(basename "$filepath") — canonical multi-line pattern MISSING"
                P6_FAIL=$((P6_FAIL + 1))
            else
                echo -e "  ${YELLOW}WARN${NC} $(basename "$filepath") — canonical multi-line pattern missing"
                WARN_COUNT=$((WARN_COUNT + 1))
            fi
        else
            echo -e "  ${GREEN}PASS${NC} $(basename "$filepath") — no anti-pattern multi-line match"
            P6_PASS=$((P6_PASS + 1))
        fi
    fi
}

ml_topics=$(get_multiline_topics)

for topic in $ml_topics; do
    canonical_pattern=$(get_field "$topic" "canonical_pattern")
    anti_pattern=$(get_field "$topic" "anti_pattern")
    severity=$(get_field "$topic" "severity")
    description=$(get_field "$topic" "description")
    consumer_files=$(get_consumer_files "$topic")

    P6_TOPICS=$((P6_TOPICS + 1))
    severity_upper=$(echo "$severity" | tr '[:lower:]' '[:upper:]')
    echo -e "${CYAN}[${severity_upper}] ${topic}${NC} (multi-line)"
    echo "  $description"

    if [[ -z "$consumer_files" ]]; then
        echo -e "  ${YELLOW}SKIP${NC} No consumer files defined"
        P6_SKIP=$((P6_SKIP + 1))
        echo ""
        continue
    fi

    while IFS= read -r cf; do
        [[ -z "$cf" ]] && continue
        filepath="$REFS_DIR/$cf"

        # Rule consumers: multi-line code patterns are not expected in prose → SKIP
        if is_rule_consumer "$cf"; then
            echo -e "  ${YELLOW}SKIP${NC} $(basename "$filepath") (rule consumer)"
            P6_SKIP=$((P6_SKIP + 1))
            continue
        fi

        # Check canonical multi-line pattern if it contains \n
        if [[ -n "$canonical_pattern" ]] && [[ "$canonical_pattern" == *'\n'* ]]; then
            check_multiline_pattern "canonical" "$canonical_pattern" "$filepath" "$topic" "$severity"
        fi

        # Check anti-pattern multi-line if it contains \n
        if [[ -n "$anti_pattern" ]] && [[ "$anti_pattern" == *'\n'* ]]; then
            check_multiline_pattern "anti" "$anti_pattern" "$filepath" "$topic" "$severity"
        fi
    done <<< "$consumer_files"

    echo ""
done

echo -e "  Phase 6: Topics=${CYAN}${P6_TOPICS}${NC}  PASS=${GREEN}${P6_PASS}${NC}  FAIL=${RED}${P6_FAIL}${NC}  SKIP=${YELLOW}${P6_SKIP}${NC}"
echo ""

# ─────────────────────────────────────────────────────────────
# Summary (all 6 phases)
# ─────────────────────────────────────────────────────────────

TOTAL_PASS=$((PASS_COUNT + P3_PASS + P4_PASS + P6_PASS))
TOTAL_FAIL=$((FAIL_COUNT + P3_FAIL + P4_FAIL + P6_FAIL))
TOTAL_SKIP=$((SKIP_COUNT + P1_SKIP + P3_SKIP + P6_SKIP))
TOTAL_WARN=$((WARN_COUNT + MARKER_WARN + P5_WARN))
TOTAL_CHECKS=$((TOTAL_PASS + TOTAL_FAIL + TOTAL_SKIP))

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  CONSISTENCY REPORT v3.2                      ║"
echo "╠════════════════════════════════════════════════════════════════╣"
printf "║  Topics: %-3d │ Checks: %-3d                                  ║\n" "$TOPIC_COUNT" "$TOTAL_CHECKS"
printf "║  PASS: %-3d   │ FAIL: %-3d  │ SKIP: %-3d  │ WARN: %-3d        ║\n" "$TOTAL_PASS" "$TOTAL_FAIL" "$TOTAL_SKIP" "$TOTAL_WARN"
echo "╠════════════════════════════════════════════════════════════════╣"
printf "║  Phase 1 (Anti-pattern):  PASS=%-3d FAIL=%-3d SKIP=%-3d       ║\n" "$PASS_COUNT" "$FAIL_COUNT" "$P1_SKIP"
printf "║  Phase 2 (Markers):       found=%-3d missing=%-3d             ║\n" "$MARKER_PASS" "$MARKER_WARN"
printf "║  Phase 3 (Canonical):     PASS=%-3d FAIL=%-3d SKIP=%-3d       ║\n" "$P3_PASS" "$P3_FAIL" "$P3_SKIP"
printf "║  Phase 4 (Authority):     PASS=%-3d FAIL=%-3d                 ║\n" "$P4_PASS" "$P4_FAIL"
printf "║  Phase 5 (Line hints):    PASS=%-3d WARN=%-3d                 ║\n" "$P5_PASS" "$P5_WARN"
printf "║  Phase 6 (Multi-line):    PASS=%-3d FAIL=%-3d SKIP=%-3d       ║\n" "$P6_PASS" "$P6_FAIL" "$P6_SKIP"
echo "╠════════════════════════════════════════════════════════════════╣"

if [[ $TOTAL_FAIL -eq 0 ]]; then
    echo -e "║  ${GREEN}STATUS: ALL CHECKS PASSED${NC}                                   ║"
    if [[ $TOTAL_WARN -gt 0 ]]; then
        echo -e "║  ${YELLOW}NOTE: $TOTAL_WARN warning(s) — review recommended${NC}                     ║"
    fi
    echo "╚════════════════════════════════════════════════════════════════╝"
    exit 0
else
    echo -e "║  ${RED}STATUS: $TOTAL_FAIL VIOLATION(S) FOUND${NC}                                ║"
    echo "║                                                              ║"
    echo "║  Fix consumer/authority files to restore consistency.        ║"
    echo "║  See AUTHORITY-REGISTRY.yaml for topic → authority mapping.  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    exit 1
fi
