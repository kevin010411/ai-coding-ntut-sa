#!/usr/bin/env bash
# test-validate-generated-code.sh — Regression tests for Gate 2.5 awk parsers
#
# Tests the parse_rules() and parse_cross_file_rules() awk parsers from
# validate-generated-code.sh against the real deterministic-review-rules.yaml.
#
# Validates:
#   - Rule count per section (forbidden/required/structure/cross_file)
#   - Section boundary parsing (historical bug: last rule in each section got polluted)
#   - Specific field extraction (pattern, precondition, exclude_context, etc.)
#   - Field delimiter integrity (12 § separators per rule)
#
# Usage:
#   bash .claude/skills/ezddd-java/scripts/test-validate-generated-code.sh
#
# Exit codes:
#   0 = all tests passed
#   1 = one or more tests failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RULES_FILE="$SKILL_DIR/references/gate25/deterministic-review-rules.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0

# ─────────────────────────────────────────────────────────────
# Assert helpers
# ─────────────────────────────────────────────────────────────

assert_eq() {
    local test_id="$1"
    local expected="$2"
    local actual="$3"
    local desc="$4"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}PASS${NC} $test_id: $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $test_id: $desc"
        echo -e "    expected: ${BOLD}$expected${NC}"
        echo -e "    actual:   ${BOLD}$actual${NC}"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local test_id="$1"
    local haystack="$2"
    local needle="$3"
    local desc="$4"

    if echo "$haystack" | grep -qF "$needle"; then
        echo -e "  ${GREEN}PASS${NC} $test_id: $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $test_id: $desc"
        echo -e "    expected to contain: ${BOLD}$needle${NC}"
        echo -e "    in: ${BOLD}$(echo "$haystack" | head -1)${NC}"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local test_id="$1"
    local haystack="$2"
    local needle="$3"
    local desc="$4"

    if echo "$haystack" | grep -qF "$needle"; then
        echo -e "  ${RED}FAIL${NC} $test_id: $desc"
        echo -e "    should NOT contain: ${BOLD}$needle${NC}"
        echo -e "    in: ${BOLD}$(echo "$haystack" | head -1)${NC}"
        FAIL=$((FAIL + 1))
    else
        echo -e "  ${GREEN}PASS${NC} $test_id: $desc"
        PASS=$((PASS + 1))
    fi
}

# ─────────────────────────────────────────────────────────────
# Embedded parse functions (copied from validate-generated-code.sh:128-182)
# These are the exact awk programs used in production.
# ─────────────────────────────────────────────────────────────

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
# Banner
# ─────────────────────────────────────────────────────────────

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   Gate 2.5 Parser Regression Tests                           ║"
echo "║   Testing awk parsers against real YAML rules                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [[ ! -f "$RULES_FILE" ]]; then
    echo -e "${RED}ERROR: Rules file not found: $RULES_FILE${NC}"
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# TC-1 ~ TC-5: Rule count tests
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══ Rule Count Tests ═══${NC}"
echo ""

forbidden_output=$(parse_rules "forbidden")
required_output=$(parse_rules "required")
structure_output=$(parse_rules "structure")
cross_file_output=$(parse_cross_file_rules)

forbidden_count=$(echo "$forbidden_output" | grep -c '.' || true)
required_count=$(echo "$required_output" | grep -c '.' || true)
structure_count=$(echo "$structure_output" | grep -c '.' || true)
cross_file_count=$(echo "$cross_file_output" | grep -c '.' || true)

assert_eq "TC-01" "27" "$forbidden_count" "forbidden rule count"
assert_eq "TC-02" "14" "$required_count" "required rule count"
assert_eq "TC-03" "5" "$structure_count" "structure rule count"
assert_eq "TC-04" "1" "$cross_file_count" "cross_file rule count"

# TC-05: Every forbidden/required/structure rule has exactly 12 § delimiters (= 12 fields)
bad_field_count=0
while IFS= read -r line; do
    delimiters=$(echo "$line" | awk -F'§' '{print NF}')
    if [[ "$delimiters" -ne 12 ]]; then
        bad_field_count=$((bad_field_count + 1))
        echo -e "  ${RED}BAD${NC} field count=$delimiters: $(echo "$line" | cut -c1-60)..."
    fi
done <<< "$forbidden_output"
while IFS= read -r line; do
    delimiters=$(echo "$line" | awk -F'§' '{print NF}')
    if [[ "$delimiters" -ne 12 ]]; then
        bad_field_count=$((bad_field_count + 1))
        echo -e "  ${RED}BAD${NC} field count=$delimiters: $(echo "$line" | cut -c1-60)..."
    fi
done <<< "$required_output"
while IFS= read -r line; do
    delimiters=$(echo "$line" | awk -F'§' '{print NF}')
    if [[ "$delimiters" -ne 12 ]]; then
        bad_field_count=$((bad_field_count + 1))
        echo -e "  ${RED}BAD${NC} field count=$delimiters: $(echo "$line" | cut -c1-60)..."
    fi
done <<< "$structure_output"

assert_eq "TC-05" "0" "$bad_field_count" "all forbidden/required/structure rules have 12 § fields"

echo ""

# ─────────────────────────────────────────────────────────────
# TC-06 ~ TC-10: Section boundary tests (historical bug regression)
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══ Section Boundary Tests (regression) ═══${NC}"
echo ""

# TC-06: F-27 (last forbidden rule) — desc must NOT contain "required" keyword
f27_line=$(echo "$forbidden_output" | grep '^F-27§')
f27_desc=$(echo "$f27_line" | awk -F'§' '{print $2}')
f27_pattern=$(echo "$f27_line" | awk -F'§' '{print $3}')

assert_not_contains "TC-06a" "$f27_desc" "required" "F-27 desc not polluted by 'required' section"
assert_not_contains "TC-06b" "$f27_desc" "structure" "F-27 desc not polluted by 'structure' section"
assert_contains "TC-06c" "$f27_pattern" "env" "F-27 pattern contains 'env' (env.put check)"

# TC-07: R-14 (last required rule) — desc must NOT contain "structure" keyword
r14_line=$(echo "$required_output" | grep '^R-14§')
r14_desc=$(echo "$r14_line" | awk -F'§' '{print $2}')
r14_pattern=$(echo "$r14_line" | awk -F'§' '{print $3}')

assert_not_contains "TC-07a" "$r14_desc" "structure" "R-14 desc not polluted by 'structure' section"
assert_contains "TC-07b" "$r14_pattern" "setUpEventCapture" "R-14 pattern contains 'setUpEventCapture'"

# TC-08: S-05 (last structure rule) — file_pattern must be about Config
s05_line=$(echo "$structure_output" | grep '^S-05§')
s05_fpat=$(echo "$s05_line" | awk -F'§' '{print $8}')

assert_contains "TC-08a" "$s05_fpat" "Config" "S-05 file_pattern contains 'Config'"
assert_not_contains "TC-08b" "$s05_fpat" "cross_file" "S-05 file_pattern not polluted by 'cross_file'"

# TC-09: X-01 (last cross_file rule) — desc must NOT contain "testsuite"
x01_line=$(echo "$cross_file_output" | grep '^X-01§')
x01_desc=$(echo "$x01_line" | awk -F'§' '{print $2}')

assert_not_contains "TC-09" "$x01_desc" "testsuite" "X-01 desc not polluted by 'testsuite' section"

# TC-10: ALL forbidden rules — no field should contain section markers
all_forbidden_has_leak=0
while IFS= read -r line; do
    if echo "$line" | grep -qF "required:"; then
        all_forbidden_has_leak=1
        echo -e "  ${RED}LEAK${NC} forbidden rule contains 'required:': $(echo "$line" | cut -c1-80)"
    fi
    if echo "$line" | grep -qF "structure:"; then
        all_forbidden_has_leak=1
        echo -e "  ${RED}LEAK${NC} forbidden rule contains 'structure:': $(echo "$line" | cut -c1-80)"
    fi
done <<< "$forbidden_output"

assert_eq "TC-10" "0" "$all_forbidden_has_leak" "no forbidden rule fields contain section markers"

echo ""

# ─────────────────────────────────────────────────────────────
# TC-11 ~ TC-15: Specific field validation
# ─────────────────────────────────────────────────────────────

echo -e "${BOLD}═══ Specific Field Validation ═══${NC}"
echo ""

# TC-11: F-01 pattern must be the exact @Service/@Component regex
f01_line=$(echo "$forbidden_output" | grep '^F-01§')
f01_pattern=$(echo "$f01_line" | awk -F'§' '{print $3}')

assert_eq "TC-11" '^\s*@(Service|Component)\s*$' "$f01_pattern" "F-01 pattern is exact @Service/@Component regex"

# TC-12: R-01 precondition_pattern contains "BaseSpringBootTest"
r01_line=$(echo "$required_output" | grep '^R-01§')
r01_precond=$(echo "$r01_line" | awk -F'§' '{print $7}')

assert_contains "TC-12" "$r01_precond" "BaseSpringBootTest" "R-01 precondition contains 'BaseSpringBootTest'"

# TC-13: R-01 negative_precondition contains "BaseUseCaseTest"
r01_negpre=$(echo "$r01_line" | awk -F'§' '{print $11}')

assert_contains "TC-13" "$r01_negpre" "BaseUseCaseTest" "R-01 negative_precondition contains 'BaseUseCaseTest'"

# TC-14: S-02 negative_package contains "reactor"
s02_line=$(echo "$structure_output" | grep '^S-02§')
s02_negpkg=$(echo "$s02_line" | awk -F'§' '{print $12}')

assert_contains "TC-14" "$s02_negpkg" "reactor" "S-02 negative_package contains 'reactor'"

# TC-15: F-09 exclude_context is non-empty (has exclude markers)
f09_line=$(echo "$forbidden_output" | grep '^F-09§')
f09_exclude=$(echo "$f09_line" | awk -F'§' '{print $6}')

if [[ -n "$f09_exclude" ]]; then
    echo -e "  ${GREEN}PASS${NC} TC-15: F-09 exclude_context is non-empty ($f09_exclude)"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} TC-15: F-09 exclude_context should be non-empty"
    FAIL=$((FAIL + 1))
fi

echo ""

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────

TOTAL=$((PASS + FAIL))

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              PARSER REGRESSION TEST RESULTS                   ║"
echo "╠════════════════════════════════════════════════════════════════╣"
printf "║  Tests: %-3d │ PASS: %-3d │ FAIL: %-3d                        ║\n" "$TOTAL" "$PASS" "$FAIL"
echo "╠════════════════════════════════════════════════════════════════╣"

if [[ $FAIL -eq 0 ]]; then
    echo -e "║  ${GREEN}STATUS: ALL TESTS PASSED${NC}                                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    exit 0
else
    echo -e "║  ${RED}STATUS: $FAIL TEST(S) FAILED${NC}                                       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    exit 1
fi
