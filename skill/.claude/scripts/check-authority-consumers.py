#!/usr/bin/env python3
"""
SSOA Authority Consumer Checker v2.2 — PostToolUse Hook

Bidirectional consistency validation:
  A) Modify authority file → list consumers + validate alignment
  B) Modify consumer file → reverse-lookup authority, validate alignment

Usage: Invoked automatically by Claude Code PostToolUse hook.
       Reads tool-use JSON from stdin, writes JSON to stdout.
"""

from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, Optional


# ── Constants ──────────────────────────────────────────────────────────

REFERENCES_PREFIX = ".claude/skills/ezddd-java/references/"
REGISTRY_RELATIVE = ".claude/skills/ezddd-java/references/AUTHORITY-REGISTRY.yaml"


# ── YAML unescape helper ─────────────────────────────────────────────

def _yaml_unescape(s: str) -> str:
    """
    De-escape YAML double-quoted backslash pairs (\\\\  →  \\).

    The YAML registry uses double-quoted strings like:
        canonical_pattern: "DateProvider\\.now\\(\\)"
    In real YAML, \\\\ represents a single backslash.  But since we parse
    with regex (not a YAML library), the literal '\\\\' stays in the
    captured group.  This function converts every consecutive backslash
    pair into a single backslash so the regex pattern works correctly.

    Single-quoted YAML patterns (which have only single backslashes)
    are unaffected because there are no pairs to replace.
    """
    return s.replace("\\\\", "\\")


# ── YAML regex state-machine parser ───────────────────────────────────

def parse_rule_consumers(registry_path: str) -> set[str]:
    """
    Parse the meta.rule_consumers list from AUTHORITY-REGISTRY.yaml.
    These are consumer files that describe rules in prose/YAML — they should
    be SKIPPED during pattern validation (same as check-pattern-consistency.sh).
    """
    rule_consumers: set[str] = set()
    in_rule_consumers = False

    with open(registry_path, "r", encoding="utf-8") as f:
        for line in f:
            if re.match(r"^\s+rule_consumers:", line):
                in_rule_consumers = True
                continue
            if in_rule_consumers:
                m = re.match(r'^\s+- "(.+)"', line)
                if m:
                    rule_consumers.add(m.group(1))
                elif not re.match(r"^\s*$", line) and not re.match(r"^\s*#", line):
                    # End of rule_consumers list
                    in_rule_consumers = False

    return rule_consumers


def parse_registry(registry_path: str) -> dict[str, list[dict]]:
    """
    Parse AUTHORITY-REGISTRY.yaml with a regex state machine.
    Returns: { authority_relative_path: [ {topic, severity, canonical_pattern, anti_pattern, consumers: [{file, section}]} ] }

    Authority paths in the YAML are relative to references/ dir,
    except "CLAUDE.md" which is at project root.
    """
    authority_map: dict[str, list[dict]] = {}

    re_topic = re.compile(r"^  (\w+):$")
    re_authority = re.compile(r'^\s+authority:\s*"(.+)"')
    re_severity = re.compile(r"^\s+severity:\s*(\w+)")
    re_canonical = re.compile(r"""^\s+canonical_pattern:\s*['"](.+)['"]""")
    re_anti = re.compile(r"""^\s+anti_pattern:\s*['"](.+)['"]""")
    re_consumers_start = re.compile(r"^\s+(consumers|template_consumers|jit_consumers):")
    re_consumer_file = re.compile(r'^\s+- file:\s*"(.+)"')
    re_consumer_section = re.compile(r'^\s+section:\s*"(.+)"')

    topic_name = None
    authority_file = None
    severity = None
    canonical_pattern = None
    anti_pattern = None
    consumers: list[dict] = []
    in_consumers = False
    current_consumer_file = None

    with open(registry_path, "r", encoding="utf-8") as f:
        for line in f:
            # New topic
            m = re_topic.match(line)
            if m:
                # Flush previous topic
                if topic_name and authority_file:
                    _flush_topic(authority_map, authority_file, topic_name,
                                 severity, canonical_pattern, anti_pattern, consumers)
                topic_name = m.group(1)
                authority_file = None
                severity = None
                canonical_pattern = None
                anti_pattern = None
                consumers = []
                in_consumers = False
                current_consumer_file = None
                continue

            # Authority file
            m = re_authority.match(line)
            if m:
                authority_file = m.group(1)
                continue

            # Severity
            m = re_severity.match(line)
            if m:
                severity = m.group(1)
                continue

            # Canonical pattern
            m = re_canonical.match(line)
            if m:
                canonical_pattern = _yaml_unescape(m.group(1))
                continue

            # Anti pattern
            m = re_anti.match(line)
            if m:
                anti_pattern = _yaml_unescape(m.group(1))
                continue

            # Start of consumers list (consumers, template_consumers, jit_consumers)
            m = re_consumers_start.match(line)
            if m:
                # Check if it's an empty list (consumers: [])
                if re.match(r"^\s+\w+:\s*\[\]", line):
                    continue
                in_consumers = True
                current_consumer_file = None
                continue

            # Exit consumers on non-indented or different key
            if in_consumers:
                if re.match(r"^\s{4}\w", line) and not re.match(r"^\s+- file:", line) and not re.match(r"^\s+section:", line) and not re.match(r"^\s+rule_number:", line):
                    in_consumers = False
                    current_consumer_file = None

            if in_consumers:
                m = re_consumer_file.match(line)
                if m:
                    current_consumer_file = m.group(1)
                    continue

                m = re_consumer_section.match(line)
                if m and current_consumer_file:
                    consumers.append({"file": current_consumer_file, "section": m.group(1)})
                    current_consumer_file = None
                    continue

        # Flush last topic
        if topic_name and authority_file:
            _flush_topic(authority_map, authority_file, topic_name,
                         severity, canonical_pattern, anti_pattern, consumers)

    return authority_map


def _flush_topic(
    authority_map: dict[str, list[dict]],
    authority_file: str,
    topic_name: str,
    severity: str | None,
    canonical_pattern: str | None,
    anti_pattern: str | None,
    consumers: list[dict],
) -> None:
    """Accumulate topic info under the authority file key."""
    entry = {
        "topic": topic_name,
        "severity": severity or "unknown",
        "canonical_pattern": canonical_pattern,
        "anti_pattern": anti_pattern,
        "consumers": list(consumers),
    }
    authority_map.setdefault(authority_file, []).append(entry)


# ── Reverse index: consumer → topics ─────────────────────────────────

def build_consumer_index(authority_map: dict[str, list[dict]]) -> dict[str, list[dict]]:
    """
    Build reverse index: { consumer_file_path: [ {topic, severity, canonical_pattern, anti_pattern, authority} ] }
    """
    consumer_index: dict[str, list[dict]] = {}
    for authority_key, topics in authority_map.items():
        for t in topics:
            for c in t["consumers"]:
                entry = {
                    "topic": t["topic"],
                    "severity": t["severity"],
                    "canonical_pattern": t.get("canonical_pattern"),
                    "anti_pattern": t.get("anti_pattern"),
                    "authority": authority_key,
                    "section": c.get("section", ""),
                }
                consumer_index.setdefault(c["file"], []).append(entry)
    return consumer_index


# ── Path normalisation ────────────────────────────────────────────────

def normalise_to_authority_key(file_path: str, project_dir: str) -> str | None:
    """
    Convert an absolute file path to the authority key used in the registry.
    """
    rel = os.path.relpath(file_path, project_dir)

    if rel == "CLAUDE.md":
        return "CLAUDE.md"

    if rel.startswith(REFERENCES_PREFIX):
        return rel[len(REFERENCES_PREFIX):]

    return None


def normalise_to_consumer_key(file_path: str, project_dir: str) -> str | None:
    """
    Convert an absolute file path to the consumer key used in the registry.
    Consumer keys are relative to references/ dir.
    """
    rel = os.path.relpath(file_path, project_dir)

    if rel.startswith(REFERENCES_PREFIX):
        return rel[len(REFERENCES_PREFIX):]

    return None


# ── Validation ───────────────────────────────────────────────────────

def _is_multiline_pattern(pattern: str | None) -> bool:
    """Check if a pattern contains literal \\n (multi-line, not suitable for grep)."""
    return pattern is not None and "\\n" in pattern


def validate_consumer_file(
    consumer_file: str,
    canonical_pattern: str | None,
    anti_pattern: str | None,
    refs_dir: str,
) -> tuple[str, str]:
    """
    Validate a single consumer file against canonical/anti patterns.
    Returns (status, detail) where status is 'pass', 'fail', or 'skip'.
    """
    filepath = os.path.join(refs_dir, consumer_file)

    if not os.path.isfile(filepath):
        return ("skip", f"{consumer_file} — file not found")

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception:
        return ("skip", f"{consumer_file} — cannot read file")

    issues = []

    # Check canonical pattern presence
    if canonical_pattern and not _is_multiline_pattern(canonical_pattern):
        try:
            if not re.search(canonical_pattern, content):
                issues.append(f"canonical pattern MISSING: {canonical_pattern}")
        except re.error:
            pass  # skip invalid regex

    # Check anti-pattern absence (exclude lines marked as wrong/negative)
    if anti_pattern and not _is_multiline_pattern(anti_pattern):
        _anti_skip_markers = [
            "❌", "WRONG", "deprecated", "FORBIDDEN", "NEVER",
            "MUST NOT", "DO NOT", "NOT ", "NO @", "// WRONG",
            "anti_pattern", "anti-pattern",
            # Fix/replace/verify instructions (documentation context)
            "Replace", "Remove", "Verify", "instead of",
            # Chinese negative markers
            "錯誤", "絕對不要", "禁止", "不要", "不可", "不允許",
            "移除", "修復", "替換", "改用", "舊",
        ]
        _context_lines = 8  # look-back window for negative context
        try:
            lines = content.splitlines()
            for i, line in enumerate(lines):
                if re.search(anti_pattern, line):
                    # Check current line AND N lines before for negative context
                    context_start = max(0, i - _context_lines)
                    context = "\n".join(lines[context_start:i + 1])
                    if any(marker in context for marker in _anti_skip_markers):
                        continue
                    issues.append(f"anti-pattern FOUND: {anti_pattern}")
                    break
        except re.error:
            pass  # skip invalid regex

    if issues:
        return ("fail", f"{consumer_file} — {'; '.join(issues)}")

    return ("pass", consumer_file)


def validate_consumers_alignment(
    topics: list[dict],
    refs_dir: str,
    rule_consumers: set[str] | None = None,
) -> list[tuple[str, str, str]]:
    """
    For each consumer in topics, validate canonical/anti pattern alignment.
    Consumers listed in rule_consumers are SKIPPED (they describe rules in prose).
    Returns list of (consumer_file, status, detail).
    """
    results: list[tuple[str, str, str]] = []
    rule_consumers = rule_consumers or set()

    for t in topics:
        canonical = t.get("canonical_pattern")
        anti = t.get("anti_pattern")

        for c in t["consumers"]:
            if c["file"] in rule_consumers:
                results.append((c["file"], "skip", f"{c['file']} (rule consumer)"))
                continue
            status, detail = validate_consumer_file(
                c["file"], canonical, anti, refs_dir
            )
            results.append((c["file"], status, detail))

    return results


# ── Output formatting ─────────────────────────────────────────────────

def format_authority_alert(authority_key: str, topics: list[dict], validation_results: list[tuple[str, str, str]]) -> str:
    """Build alert for authority file modification with validation results."""
    lines = [
        f"SSOA ALERT: You modified authority file [{authority_key}].",
        "",
    ]

    # Consumer list
    for t in topics:
        consumers = t["consumers"]
        if not consumers:
            continue
        lines.append(f"  [{t['topic']}] (severity: {t['severity']})")
        for c in consumers:
            section_part = f" \u00a7 {c['section']}" if c.get("section") else ""
            lines.append(f"    - {c['file']}{section_part}")
        lines.append("")

    # Validation results
    if validation_results:
        pass_count = sum(1 for _, s, _ in validation_results if s == "pass")
        fail_count = sum(1 for _, s, _ in validation_results if s == "fail")

        lines.append("VALIDATION RESULTS:")
        for file_key, status, detail in validation_results:
            if status == "pass":
                lines.append(f"  \u2705 {detail}")
            elif status == "fail":
                lines.append(f"  \u274c {detail}")
            else:
                lines.append(f"  \u23ed {detail}")

        lines.append("")
        if fail_count > 0:
            lines.append(f"ACTION REQUIRED: Fix {fail_count} violation(s) in consumer files.")
            lines.append("Ensure consumers contain the canonical pattern and do not contain anti-patterns.")
        else:
            lines.append(f"All {pass_count} consumer(s) validated — alignment confirmed.")

    return "\n".join(lines)


def format_consumer_alert(consumer_key: str, topic_entries: list[dict], validation_results: list[tuple[str, str, str]]) -> str:
    """Build alert for consumer file modification with reverse-lookup validation."""
    lines = [
        f"SSOA ALERT: You modified consumer file [{consumer_key}].",
        f"This file is governed by {len(topic_entries)} authority topic(s):",
        "",
    ]

    for entry in topic_entries:
        lines.append(f"  [{entry['topic']}] authority: {entry['authority']} (severity: {entry['severity']})")

    lines.append("")

    if validation_results:
        fail_count = sum(1 for _, s, _ in validation_results if s == "fail")

        lines.append("VALIDATION RESULTS:")
        for _, status, detail in validation_results:
            if status == "pass":
                lines.append(f"  \u2705 {detail}")
            elif status == "fail":
                lines.append(f"  \u274c {detail}")
            else:
                lines.append(f"  \u23ed {detail}")

        lines.append("")
        if fail_count > 0:
            lines.append(f"ACTION REQUIRED: Fix {fail_count} violation(s) — this consumer may have drifted from its authority.")
        else:
            lines.append("Consumer file aligns with all authority topics.")

    return "\n".join(lines)


# ── Main ──────────────────────────────────────────────────────────────

def main() -> None:
    # Read PostToolUse JSON from stdin
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            sys.exit(0)
        event = json.loads(raw)
    except (json.JSONDecodeError, Exception):
        sys.exit(0)

    # Extract file_path from tool_input
    tool_input = event.get("tool_input", {})
    file_path = tool_input.get("file_path")
    if not file_path:
        sys.exit(0)

    # Resolve project directory
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_dir:
        # Fallback: derive from script location  (.claude/scripts/ → project root)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_dir = os.path.dirname(os.path.dirname(script_dir))

    refs_dir = os.path.join(project_dir, REFERENCES_PREFIX.rstrip("/"))

    # Parse registry
    registry_path = os.path.join(project_dir, REGISTRY_RELATIVE)
    if not os.path.isfile(registry_path):
        sys.exit(0)

    authority_map = parse_registry(registry_path)
    rule_consumers = parse_rule_consumers(registry_path)

    # ── Path A: Check if this file is an authority ────────────────

    authority_key = normalise_to_authority_key(file_path, project_dir)
    if authority_key and authority_key in authority_map:
        topics = authority_map[authority_key]
        topics_with_consumers = [t for t in topics if t["consumers"]]

        if topics_with_consumers:
            validation_results = validate_consumers_alignment(topics_with_consumers, refs_dir, rule_consumers)
            alert_text = format_authority_alert(authority_key, topics_with_consumers, validation_results)

            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": alert_text,
                }
            }
            print(json.dumps(output))
            sys.exit(0)

    # ── Path B: Check if this file is a consumer ─────────────────

    consumer_key = normalise_to_consumer_key(file_path, project_dir)
    if consumer_key:
        # Rule consumers: skip validation, just show advisory
        if consumer_key in rule_consumers:
            topic_entries_for_msg = build_consumer_index(authority_map).get(consumer_key, [])
            if topic_entries_for_msg:
                alert_text = format_consumer_alert(
                    consumer_key, topic_entries_for_msg,
                    [(consumer_key, "skip", f"{consumer_key} (rule consumer — validation skipped)")]
                )
                output = {
                    "hookSpecificOutput": {
                        "hookEventName": "PostToolUse",
                        "additionalContext": alert_text,
                    }
                }
                print(json.dumps(output))
            sys.exit(0)

        consumer_index = build_consumer_index(authority_map)
        topic_entries = consumer_index.get(consumer_key)

        if topic_entries:
            # Validate this consumer against each authority topic
            validation_results: list[tuple[str, str, str]] = []
            for entry in topic_entries:
                status, detail = validate_consumer_file(
                    consumer_key,
                    entry.get("canonical_pattern"),
                    entry.get("anti_pattern"),
                    refs_dir,
                )
                validation_results.append((consumer_key, status, detail))

            alert_text = format_consumer_alert(consumer_key, topic_entries, validation_results)

            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": alert_text,
                }
            }
            print(json.dumps(output))
            sys.exit(0)

    # Not an authority or consumer — silent pass
    sys.exit(0)


if __name__ == "__main__":
    main()
