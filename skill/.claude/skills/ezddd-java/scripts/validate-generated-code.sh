#!/usr/bin/env bash
# validate-generated-code.sh — Gate 2.5: Deterministic Review Gate
#
# 100% pattern matching, 0% LLM judgment.
# Reads rules from references/gate25/deterministic-review-rules.yaml
# and validates generated Java files against FORBIDDEN/REQUIRED/STRUCTURE rules.
#
# Usage:
#   ./validate-generated-code.sh --aggregate product
#   ./validate-generated-code.sh --aggregate product --json
#   ./validate-generated-code.sh --files-from filelist.txt
#   echo "src/.../Product.java" | ./validate-generated-code.sh
#
# Exit codes:
#   0 = all checks passed (WARN allowed)
#   1 = CRITICAL violations found (BLOCKING)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RULES_FILE="$SKILL_DIR/references/gate25/deterministic-review-rules.yaml"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
CRITICAL_COUNT=0
WARN_COUNT=0
PASS_COUNT=0
SKIP_COUNT=0
TOTAL_RULES=0

# JSON output mode
JSON_OUTPUT=false
declare -a VIOLATIONS_JSON_ENTRIES=()

# Timing
START_TIME=$(date +%s)

# ─────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────

AGGREGATE=""
FILES_FROM=""
declare -a TARGET_FILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --aggregate|-a)
            AGGREGATE="$2"
            shift 2
            ;;
        --files-from|-f)
            FILES_FROM="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --help|-h)
            echo "Usage:"
            echo "  $0 --aggregate <name>      Scan all Java files for an aggregate"
            echo "  $0 --aggregate <name> --json   Output results as JSON"
            echo "  $0 --files-from <file>      Read file list from a file"
            echo "  echo 'path' | $0            Read file list from stdin"
            exit 0
            ;;
        *)
            TARGET_FILES+=("$1")
            shift
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────
# Collect target files
# ─────────────────────────────────────────────────────────────

collect_files() {
    if [[ -n "$AGGREGATE" ]]; then
        local agg_lower
        agg_lower=$(echo "$AGGREGATE" | tr '[:upper:]' '[:lower:]')
        # Find all Java files for this aggregate (main + test)
        find "$SRC_DIR" -path "*/$agg_lower/*.java" -type f 2>/dev/null | sort
    elif [[ -n "$FILES_FROM" ]]; then
        cat "$FILES_FROM"
    elif [[ ${#TARGET_FILES[@]} -gt 0 ]]; then
        printf '%s\n' "${TARGET_FILES[@]}"
    elif [[ ! -t 0 ]]; then
        cat
    else
        echo -e "${RED}ERROR: No files specified. Use --aggregate, --files-from, or pipe file list.${NC}" >&2
        exit 1
    fi
}

declare -a ALL_FILES=()
while IFS= read -r line; do
    [[ -n "$line" ]] && ALL_FILES+=("$line")
done < <(collect_files)

if [[ ${#ALL_FILES[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR: No Java files found.${NC}" >&2
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Lightweight YAML parser (reuses approach from check-pattern-consistency.sh)
# ─────────────────────────────────────────────────────────────

if [[ ! -f "$RULES_FILE" ]]; then
    echo -e "${RED}ERROR: Rules file not found: $RULES_FILE${NC}" >&2
    exit 1
fi

# Parse a section (forbidden/required/structure/cross_file) and extract rule fields
# Returns: id|description|pattern|target|severity|exclude_context|precondition_pattern|file_pattern|package_must_contain|exclude_pattern|negative_precondition|negative_package
parse_rules() {
    local section="$1"
    awk -v section="$section" '
    BEGIN { in_section=0; in_rule=0; id=""; desc=""; pat=""; tgt=""; sev=""; exc=""; pre=""; fpat=""; pmust=""; exclpat=""; negpre=""; negpkg="" }
    $0 ~ "^" section ":" { in_section=1; next }
    in_section && /^[a-z_]+:/ { if (index($0, section ":") != 1) { in_section=0; in_rule=0 } }
    in_section && /^  - id:/ {
        if (id != "") {
            print id "§" desc "§" pat "§" tgt "§" sev "§" exc "§" pre "§" fpat "§" pmust "§" exclpat "§" negpre "§" negpkg
        }
        id=$0; sub(/.*id: */, "", id); gsub(/"/, "", id)
        desc=""; pat=""; tgt=""; sev=""; exc=""; pre=""; fpat=""; pmust=""; exclpat=""; negpre=""; negpkg=""
        in_rule=1; next
    }
    in_rule && /^    description:/ { desc=$0; sub(/.*description: */, "", desc); gsub(/^"|"$/, "", desc) }
    in_rule && /^    pattern:/ { pat=$0; sub(/.*pattern: */, "", pat); gsub(/^'"'"'|'"'"'$/, "", pat) }
    in_rule && /^    target:/ { tgt=$0; sub(/.*target: */, "", tgt); gsub(/^"|"$/, "", tgt) }
    in_rule && /^    severity:/ { sev=$0; sub(/.*severity: */, "", sev); gsub(/^"|"$/, "", sev) }
    in_rule && /^    exclude_context:/ { exc=$0; sub(/.*exclude_context: */, "", exc); gsub(/^'"'"'|'"'"'$/, "", exc) }
    in_rule && /^    precondition_pattern:/ { pre=$0; sub(/.*precondition_pattern: */, "", pre); gsub(/^'"'"'|'"'"'$/, "", pre) }
    in_rule && /^    file_pattern:/ { fpat=$0; sub(/.*file_pattern: */, "", fpat); gsub(/^"|"$/, "", fpat) }
    in_rule && /^    package_must_contain:/ { pmust=$0; sub(/.*package_must_contain: */, "", pmust); gsub(/^"|"$/, "", pmust) }
    in_rule && /^    exclude_pattern:/ { exclpat=$0; sub(/.*exclude_pattern: */, "", exclpat); gsub(/^"|"$/, "", exclpat) }
    in_rule && /^    negative_precondition:/ { negpre=$0; sub(/.*negative_precondition: */, "", negpre); gsub(/^'"'"'|'"'"'$/, "", negpre) }
    in_rule && /^    negative_package:/ { negpkg=$0; sub(/.*negative_package: */, "", negpkg); gsub(/^"|"$/, "", negpkg) }
    END {
        if (id != "") {
            print id "§" desc "§" pat "§" tgt "§" sev "§" exc "§" pre "§" fpat "§" pmust "§" exclpat "§" negpre "§" negpkg
        }
    }
    ' "$RULES_FILE"
}

# Parse cross_file rules
parse_cross_file_rules() {
    awk '
    BEGIN { in_section=0; in_rule=0; id=""; desc=""; fa=""; fb=""; epat=""; sev="" }
    /^cross_file:/ { in_section=1; next }
    in_section && /^[a-z_]+:/ && !/^cross_file:/ { in_section=0 }
    in_section && /^  - id:/ {
        if (id != "") { print id "§" desc "§" fa "§" fb "§" epat "§" sev }
        id=$0; sub(/.*id: */, "", id); gsub(/"/, "", id)
        desc=""; fa=""; fb=""; epat=""; sev=""
        in_rule=1; next
    }
    in_rule && /^    description:/ { desc=$0; sub(/.*description: */, "", desc); gsub(/^"|"$/, "", desc) }
    in_rule && /^    file_a:/ { fa=$0; sub(/.*file_a: */, "", fa); gsub(/^"|"$/, "", fa) }
    in_rule && /^    file_b:/ { fb=$0; sub(/.*file_b: */, "", fb); gsub(/^"|"$/, "", fb) }
    in_rule && /^    extract_pattern:/ { epat=$0; sub(/.*extract_pattern: */, "", epat); gsub(/^'"'"'|'"'"'$/, "", epat) }
    in_rule && /^    severity:/ { sev=$0; sub(/.*severity: */, "", sev); gsub(/^"|"$/, "", sev) }
    END {
        if (id != "") { print id "§" desc "§" fa "§" fb "§" epat "§" sev }
    }
    ' "$RULES_FILE"
}

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

# Check if filename matches a glob-like target pattern (e.g., "*Service.java")
matches_target() {
    local filepath="$1"
    local target="$2"
    local filename
    filename=$(basename "$filepath")

    # Convert glob to regex
    local regex
    regex=$(echo "$target" | sed 's/\./\\./g; s/\*/.*/g')
    echo "$filename" | grep -qE "^${regex}$"
}

# Check if filename matches exclude pattern (pipe-separated)
matches_exclude() {
    local filepath="$1"
    local exclude="$2"
    [[ -z "$exclude" ]] && return 1
    local filename
    filename=$(basename "$filepath")

    local IFS='|'
    for pat in $exclude; do
        pat=$(echo "$pat" | sed 's/\./\\./g; s/\*/.*/g')
        if echo "$filename" | grep -qE "^${pat}$"; then
            return 0
        fi
    done
    return 1
}

# Check if a file contains a precondition pattern (non-comment lines)
has_precondition() {
    local filepath="$1"
    local pattern="$2"
    [[ -z "$pattern" ]] && return 0
    grep -En "$pattern" "$filepath" 2>/dev/null | grep -v '^\s*//' | grep -q '.' 2>/dev/null
}

# Record a violation
record_violation() {
    local id="$1"
    local severity="$2"
    local filepath="$3"
    local desc="$4"
    local match_lines="$5"

    local sev_upper
    sev_upper=$(echo "$severity" | tr '[:lower:]' '[:upper:]')
    local color="$YELLOW"
    if [[ "$severity" == "critical" ]]; then
        color="$RED"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    else
        WARN_COUNT=$((WARN_COUNT + 1))
    fi

    local relpath="${filepath#$PROJECT_ROOT/}"

    # Collect JSON entry for --json mode
    VIOLATIONS_JSON_ENTRIES+=("{\"id\":\"$id\",\"severity\":\"$sev_upper\",\"file\":\"${relpath}\",\"description\":\"$(echo "$desc" | sed 's/"/\\"/g')\"}")

    # Skip text output in JSON mode
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        return
    fi

    echo -e "  ${color}[$sev_upper] $id${NC}: $desc"
    echo -e "    File: $relpath"
    if [[ -n "$match_lines" ]]; then
        echo "$match_lines" | head -3 | while IFS= read -r line; do
            echo -e "    ${color}>>>${NC} $line"
        done
    fi
}

# ─────────────────────────────────────────────────────────────
# Helper: text-only output (suppressed in JSON mode)
# ─────────────────────────────────────────────────────────────

text_echo() {
    [[ "$JSON_OUTPUT" == "true" ]] && return
    echo "$@"
}

text_echo_e() {
    [[ "$JSON_OUTPUT" == "true" ]] && return
    echo -e "$@"
}

# ─────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────

text_echo ""
text_echo "╔════════════════════════════════════════════════════════════════╗"
text_echo "║     Gate 2.5: Deterministic Review Gate v1.0                  ║"
text_echo "║     100% Pattern Matching — 0% LLM Judgment                  ║"
text_echo "╚════════════════════════════════════════════════════════════════╝"
text_echo ""
text_echo_e "  Files to scan: ${BOLD}${#ALL_FILES[@]}${NC}"
if [[ -n "$AGGREGATE" ]]; then
    text_echo_e "  Aggregate: ${BOLD}$AGGREGATE${NC}"
fi
text_echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 1: FORBIDDEN pattern scan
# ─────────────────────────────────────────────────────────────

text_echo_e "${BOLD}═══ PHASE 1: FORBIDDEN Pattern Scan ═══${NC}"
text_echo ""

while IFS='§' read -r id desc pattern target severity exclude_ctx precond _fpat _pmust _exclpat; do
    [[ -z "$id" ]] && continue
    TOTAL_RULES=$((TOTAL_RULES + 1))
    rule_triggered=0

    for filepath in "${ALL_FILES[@]}"; do
        [[ ! -f "$filepath" ]] && continue

        # Check if file matches target pattern
        if ! matches_target "$filepath" "$target"; then
            continue
        fi

        # Search for forbidden pattern in non-comment lines
        # grep -En output format is "N:content", so filter comments after the line number prefix
        local_matches=$(grep -En "$pattern" "$filepath" 2>/dev/null | grep -vE '^[0-9]+:\s*//' || true)

        # Apply exclude_context filter
        if [[ -n "$exclude_ctx" && -n "$local_matches" ]]; then
            local_matches=$(echo "$local_matches" | grep -v "$exclude_ctx" || true)
        fi

        if [[ -n "$local_matches" ]]; then
            record_violation "$id" "$severity" "$filepath" "$desc" "$local_matches"
            rule_triggered=1
        fi
    done

    if [[ $rule_triggered -eq 0 ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
done < <(parse_rules "forbidden")

text_echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 2: REQUIRED pattern scan
# ─────────────────────────────────────────────────────────────

text_echo_e "${BOLD}═══ PHASE 2: REQUIRED Pattern Scan ═══${NC}"
text_echo ""

while IFS='§' read -r id desc pattern target severity exclude_ctx precond _fpat _pmust _exclpat negpre _negpkg; do
    [[ -z "$id" ]] && continue
    TOTAL_RULES=$((TOTAL_RULES + 1))
    rule_triggered=0

    for filepath in "${ALL_FILES[@]}"; do
        [[ ! -f "$filepath" ]] && continue

        if ! matches_target "$filepath" "$target"; then
            continue
        fi

        # Check precondition: only validate if the file is relevant
        if [[ -n "$precond" ]]; then
            if ! has_precondition "$filepath" "$precond"; then
                continue
            fi
        fi

        # Check negative precondition: skip if file matches (e.g., extends BaseUseCaseTest already has @DirtiesContext)
        if [[ -n "$negpre" ]]; then
            if grep -qE "$negpre" "$filepath" 2>/dev/null; then
                continue
            fi
        fi

        # File matches target (and precondition if any) — pattern MUST exist
        if ! grep -qE "$pattern" "$filepath" 2>/dev/null; then
            record_violation "$id" "$severity" "$filepath" "MISSING: $desc" ""
            rule_triggered=1
        fi
    done

    if [[ $rule_triggered -eq 0 ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
done < <(parse_rules "required")

text_echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 3: Package structure validation
# ─────────────────────────────────────────────────────────────

text_echo_e "${BOLD}═══ PHASE 3: Package Structure Validation ═══${NC}"
text_echo ""

while IFS='§' read -r id desc _pat _tgt severity _exc _pre fpat pmust exclpat _negpre negpkg; do
    [[ -z "$id" ]] && continue
    TOTAL_RULES=$((TOTAL_RULES + 1))
    rule_triggered=0
    # DEBUG: uncomment to trace field parsing
    # echo "DEBUG: id=$id fpat=$fpat pmust=$pmust negpkg=[$negpkg]" >&2

    for filepath in "${ALL_FILES[@]}"; do
        [[ ! -f "$filepath" ]] && continue
        filename=$(basename "$filepath")

        # Check file_pattern match (convert glob)
        fregex=$(echo "$fpat" | sed 's|\*\*/|.*/|g; s|\*|[^/]*|g; s|\.|\\.|g')
        if ! echo "$filepath" | grep -qE "$fregex"; then
            continue
        fi

        # Check exclude
        if [[ -n "$exclpat" ]] && matches_exclude "$filepath" "$exclpat"; then
            continue
        fi

        # Extract package declaration
        pkg_line=$(grep -m1 '^package ' "$filepath" 2>/dev/null || true)
        if [[ -z "$pkg_line" ]]; then
            continue
        fi

        # Skip if package matches negative_package (e.g., reactor services are OK in .usecase.reactor)
        if [[ -n "$negpkg" ]]; then
            if echo "$pkg_line" | grep -q "$negpkg"; then
                continue
            fi
        fi

        # Check if package contains required segment
        if ! echo "$pkg_line" | grep -q "$pmust"; then
            record_violation "$id" "$severity" "$filepath" "$desc" "$pkg_line"
            rule_triggered=1
        fi
    done

    if [[ $rule_triggered -eq 0 ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
done < <(parse_rules "structure")

text_echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 4: Cross-file consistency
# ─────────────────────────────────────────────────────────────

text_echo_e "${BOLD}═══ PHASE 4: Cross-File Consistency ═══${NC}"
text_echo ""

while IFS='§' read -r id desc file_a_pat file_b_pat extract_pat severity; do
    [[ -z "$id" ]] && continue
    TOTAL_RULES=$((TOTAL_RULES + 1))

    # Find matching file pairs
    declare -a files_a=()
    declare -a files_b=()

    fa_regex=$(echo "$file_a_pat" | sed 's/\./\\./g; s/\*/.*/g')
    fb_regex=$(echo "$file_b_pat" | sed 's/\./\\./g; s/\*/.*/g')

    for filepath in "${ALL_FILES[@]}"; do
        fname=$(basename "$filepath")
        if echo "$fname" | grep -qE "^${fa_regex}$"; then
            files_a+=("$filepath")
        fi
        if echo "$fname" | grep -qE "^${fb_regex}$"; then
            files_b+=("$filepath")
        fi
    done

    if [[ ${#files_a[@]} -eq 0 || ${#files_b[@]} -eq 0 ]]; then
        text_echo_e "  ${YELLOW}SKIP${NC} $id: Matching file pair not found"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    # Extract bean names from each file and compare
    cross_fail=0
    for fa in "${files_a[@]}"; do
        fa_base=$(basename "$fa")
        # Determine aggregate prefix
        agg_prefix=$(echo "$fa_base" | sed 's/InMemoryRepositoryConfig\.java//')

        # Find matching file_b for same aggregate
        for fb in "${files_b[@]}"; do
            fb_base=$(basename "$fb")
            fb_prefix=$(echo "$fb_base" | sed 's/OutboxRepositoryConfig\.java//')
            if [[ "$agg_prefix" != "$fb_prefix" ]]; then
                continue
            fi

            beans_a=$(grep -oE '@Bean\("[^"]+"\)' "$fa" 2>/dev/null | sort || true)
            beans_b=$(grep -oE '@Bean\("[^"]+"\)' "$fb" 2>/dev/null | sort || true)

            if [[ -n "$beans_a" && -n "$beans_b" ]]; then
                if [[ "$beans_a" != "$beans_b" ]]; then
                    record_violation "$id" "$severity" "$fa" "$desc" "$(diff <(echo "$beans_a") <(echo "$beans_b") || true)"
                    cross_fail=1
                fi
            fi
        done
    done

    if [[ $cross_fail -eq 0 ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    fi

    unset files_a files_b
done < <(parse_cross_file_rules)

text_echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 5: TestSuite @SelectPackages Coverage
# ─────────────────────────────────────────────────────────────

text_echo_e "${BOLD}═══ PHASE 5: TestSuite @SelectPackages Coverage ═══${NC}"
text_echo ""

# Determine the aggregate package to verify
AGG_PACKAGE=""
if [[ -n "$AGGREGATE" ]]; then
    # Derive package from aggregate name (e.g., "product" → find its root package)
    agg_lower=$(echo "$AGGREGATE" | tr '[:upper:]' '[:lower:]')
    # Find any Java file in the aggregate to extract root package
    sample_file=$(find "$SRC_DIR/main" -path "*/$agg_lower/*.java" -type f 2>/dev/null | head -1)
    if [[ -n "$sample_file" ]]; then
        pkg_line=$(grep -m1 '^package ' "$sample_file" 2>/dev/null || true)
        if [[ -n "$pkg_line" ]]; then
            # Extract root package up to aggregate (e.g., "tw.teddysoft.aiscrum.product.entity" → "tw.teddysoft.aiscrum.product")
            full_pkg=$(echo "$pkg_line" | sed 's/^package //; s/;.*//')
            # Keep package up to aggregate name
            AGG_PACKAGE=$(echo "$full_pkg" | sed "s/\.$agg_lower\..*/.$agg_lower/")
        fi
    fi
fi

# Find TestSuite files
INMEMORY_SUITE=$(find "$SRC_DIR/test" -name "InMemoryTestSuite.java" -type f 2>/dev/null | head -1)
OUTBOX_SUITE=$(find "$SRC_DIR/test" -name "OutboxTestSuite.java" -type f 2>/dev/null | head -1)

if [[ -z "$INMEMORY_SUITE" && -z "$OUTBOX_SUITE" ]]; then
    text_echo_e "  ${YELLOW}SKIP${NC} TS-01/TS-02: No TestSuite files found"
    SKIP_COUNT=$((SKIP_COUNT + 2))
else
    # TS-01: Check InMemoryTestSuite @SelectPackages
    TOTAL_RULES=$((TOTAL_RULES + 1))
    if [[ -n "$INMEMORY_SUITE" && -n "$AGG_PACKAGE" ]]; then
        if grep -q "$AGG_PACKAGE" "$INMEMORY_SUITE" 2>/dev/null; then
            text_echo_e "  ${GREEN}PASS${NC} TS-01: $AGG_PACKAGE found in InMemoryTestSuite @SelectPackages"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            record_violation "TS-01" "critical" "$INMEMORY_SUITE" \
                "Aggregate package '$AGG_PACKAGE' NOT in InMemoryTestSuite @SelectPackages" \
                "$(grep -n '@SelectPackages' "$INMEMORY_SUITE" 2>/dev/null || echo '  @SelectPackages not found')"
        fi
    elif [[ -z "$INMEMORY_SUITE" ]]; then
        record_violation "TS-01" "critical" "$SRC_DIR/test" \
            "InMemoryTestSuite.java not found" ""
    else
        text_echo_e "  ${YELLOW}SKIP${NC} TS-01: Cannot determine aggregate package"
        SKIP_COUNT=$((SKIP_COUNT + 1))
    fi

    # TS-02: Check OutboxTestSuite @SelectPackages
    TOTAL_RULES=$((TOTAL_RULES + 1))
    if [[ -n "$OUTBOX_SUITE" && -n "$AGG_PACKAGE" ]]; then
        if grep -q "$AGG_PACKAGE" "$OUTBOX_SUITE" 2>/dev/null; then
            text_echo_e "  ${GREEN}PASS${NC} TS-02: $AGG_PACKAGE found in OutboxTestSuite @SelectPackages"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            record_violation "TS-02" "critical" "$OUTBOX_SUITE" \
                "Aggregate package '$AGG_PACKAGE' NOT in OutboxTestSuite @SelectPackages" \
                "$(grep -n '@SelectPackages' "$OUTBOX_SUITE" 2>/dev/null || echo '  @SelectPackages not found')"
        fi
    elif [[ -z "$OUTBOX_SUITE" ]]; then
        record_violation "TS-02" "critical" "$SRC_DIR/test" \
            "OutboxTestSuite.java not found" ""
    else
        text_echo_e "  ${YELLOW}SKIP${NC} TS-02: Cannot determine aggregate package"
        SKIP_COUNT=$((SKIP_COUNT + 1))
    fi

    # TS-03: Check ProfileSetter exists in both suites
    for suite_file in "$INMEMORY_SUITE" "$OUTBOX_SUITE"; do
        [[ -z "$suite_file" || ! -f "$suite_file" ]] && continue
        TOTAL_RULES=$((TOTAL_RULES + 1))
        suite_name=$(basename "$suite_file")
        if grep -q 'ProfileSetter' "$suite_file" 2>/dev/null; then
            text_echo_e "  ${GREEN}PASS${NC} TS-03: ProfileSetter found in $suite_name"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            record_violation "TS-03" "critical" "$suite_file" \
                "ProfileSetter inner class NOT found in $suite_name (using @ActiveProfiles?)" ""
        fi
    done

    # TS-04: Reverse check — packages in @SelectPackages must have existing aggregate dirs
    # Detects stale references after aggregate removal
    for suite_file in "$INMEMORY_SUITE" "$OUTBOX_SUITE"; do
        [[ -z "$suite_file" || ! -f "$suite_file" ]] && continue
        suite_name=$(basename "$suite_file")

        # Extract packages from @SelectPackages annotation (handles multiline)
        listed_pkgs=$(sed -n '/@SelectPackages/,/})/{ s/.*"\([^"]*\)".*/\1/p; }' "$suite_file" 2>/dev/null)

        for pkg in $listed_pkgs; do
            TOTAL_RULES=$((TOTAL_RULES + 1))
            # Convert package to directory path (e.g., tw.teddysoft.aiscrum.board → tw/teddysoft/aiscrum/board)
            pkg_dir=$(echo "$pkg" | tr '.' '/')
            main_dir="$SRC_DIR/main/java/$pkg_dir"
            test_dir="$SRC_DIR/test/java/$pkg_dir"

            if [[ -d "$main_dir" || -d "$test_dir" ]]; then
                text_echo_e "  ${GREEN}PASS${NC} TS-04: $pkg has source in $suite_name"
                PASS_COUNT=$((PASS_COUNT + 1))
            else
                record_violation "TS-04" "critical" "$suite_file" \
                    "Stale package '$pkg' in $suite_name @SelectPackages — no matching src directory exists" \
                    "  Expected: $main_dir OR $test_dir"
            fi
        done
    done
fi

text_echo ""

# ─────────────────────────────────────────────────────────────
# Marker: write pass marker for Stop hook verification
# ─────────────────────────────────────────────────────────────

write_pass_marker() {
    # Only write marker if we have an aggregate name and 0 CRITICAL
    if [[ $CRITICAL_COUNT -ne 0 ]]; then
        return
    fi

    local marker_agg="${AGGREGATE:-unknown}"
    local marker_dir="$PROJECT_ROOT/.gate25-markers"
    mkdir -p "$marker_dir"

    # Compute checksum of all scanned files
    local files_hash
    files_hash=$(printf '%s\n' "${ALL_FILES[@]}" | sort | xargs cat 2>/dev/null | shasum -a 256 | cut -d' ' -f1)

    local marker_file="$marker_dir/${marker_agg}.marker.json"
    cat > "$marker_file" <<MARKEREOF
{
  "aggregate": "$marker_agg",
  "files_checksum": "$files_hash",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "critical_count": 0,
  "warn_count": $WARN_COUNT,
  "files_scanned": ${#ALL_FILES[@]},
  "rules_checked": $TOTAL_RULES
}
MARKEREOF
}

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# JSON output mode: emit structured JSON and exit
if [[ "$JSON_OUTPUT" == "true" ]]; then
    # Build violations JSON array
    local_violations_str=""
    for v in "${VIOLATIONS_JSON_ENTRIES[@]}"; do
        [[ -n "$local_violations_str" ]] && local_violations_str+=","
        local_violations_str+="$v"
    done

    cat <<JSONEOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "aggregate": "$AGGREGATE",
  "status": "$([ $CRITICAL_COUNT -eq 0 ] && echo 'passed' || echo 'failed')",
  "rules_checked": $TOTAL_RULES,
  "files_scanned": ${#ALL_FILES[@]},
  "pass": $PASS_COUNT,
  "critical": $CRITICAL_COUNT,
  "warn": $WARN_COUNT,
  "skip": $SKIP_COUNT,
  "elapsed_seconds": $ELAPSED,
  "violations": [$local_violations_str]
}
JSONEOF
    write_pass_marker
    exit $([ $CRITICAL_COUNT -eq 0 ] && echo 0 || echo 1)
fi

# Text banner output (original behavior)
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          DETERMINISTIC REVIEW GATE RESULTS                    ║"
echo "╠════════════════════════════════════════════════════════════════╣"
printf "║  Rules checked: %-3d │ Files scanned: %-3d                     ║\n" "$TOTAL_RULES" "${#ALL_FILES[@]}"
printf "║  PASS: %-3d │ CRITICAL: %-3d │ WARN: %-3d │ SKIP: %-3d          ║\n" "$PASS_COUNT" "$CRITICAL_COUNT" "$WARN_COUNT" "$SKIP_COUNT"
printf "║  Time: %ds                                                    ║\n" "$ELAPSED"
echo "╠════════════════════════════════════════════════════════════════╣"

if [[ $CRITICAL_COUNT -eq 0 ]]; then
    echo -e "║  ${GREEN}STATUS: PASS${NC} (0 CRITICAL violations)                          ║"
    if [[ $WARN_COUNT -gt 0 ]]; then
        echo -e "║  ${YELLOW}NOTE: $WARN_COUNT warning(s) — review recommended${NC}                    ║"
    fi
    echo "╚════════════════════════════════════════════════════════════════╝"
    write_pass_marker
    exit 0
else
    echo -e "║  ${RED}STATUS: BLOCKED${NC} ($CRITICAL_COUNT CRITICAL violation(s) found)            ║"
    echo "║                                                              ║"
    echo "║  Fix all CRITICAL violations before proceeding.              ║"
    echo "║  Return to Step 4 (Code Generation) to fix issues.          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    exit 1
fi
