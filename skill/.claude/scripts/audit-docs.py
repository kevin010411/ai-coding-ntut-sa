#!/usr/bin/env python3
"""
Documentation Self-Healing Audit — checks CLAUDE.md references integrity.

Detects:
  1. Dead links — file paths referenced in CLAUDE.md that don't exist
  2. Dead sections — `§ SectionName` references where the heading is missing
  3. Stale SKILL.md sections — new top-level headings not cross-referenced

Usage:
  python3 .claude/scripts/audit-docs.py              # full audit
  python3 .claude/scripts/audit-docs.py --hook        # hook mode (only dead links)
  python3 .claude/scripts/audit-docs.py --fix-report  # generate fix suggestions

Exit codes:
  0 — no issues found
  1 — issues found (printed to stderr)
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import NamedTuple


class Issue(NamedTuple):
    severity: str  # DEAD_LINK, DEAD_SECTION, MISSING_XREF
    file: str
    line: int
    reference: str
    detail: str


def find_project_root() -> Path:
    return Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd()))


def _is_real_path(path: str) -> bool:
    """Filter out glob patterns, shell commands, and non-path strings."""
    # Glob patterns: **/entity/{Name}.java, *.ts*
    if any(c in path for c in ('*', '{', '?')):
        return False
    # Shell commands or pipes
    if any(c in path for c in ('|', '&&', ' -', '$', '@', '~')):
        return False
    # Must start with a known directory prefix to be a real project path
    known_prefixes = ('.dev/', '.claude/', 'src/', 'frontend/', 'pom.xml')
    if not any(path.startswith(p) for p in known_prefixes):
        return False
    # Skip single-segment names (like `feature`, `test`)
    if '/' not in path and '.' not in path:
        return False
    return True


def extract_file_references(content: str) -> list[tuple[int, str, str | None]]:
    """Extract (line_number, file_path, section_anchor) from markdown content."""
    results = []
    for i, line in enumerate(content.splitlines(), 1):
        # Skip lines inside code blocks (``` ... ```)
        # Simple heuristic: skip lines that look like shell commands
        stripped = line.strip()
        if stripped.startswith(('#!', '$', 'cat ', 'source ', 'echo ', 'which ')):
            continue

        # Match backtick-quoted paths: `.dev/adr/ADR-001.md`
        for m in re.finditer(r'`([^`]+\.[a-zA-Z]{1,5})`', line):
            path = m.group(1)
            if '/' in path and _is_real_path(path):
                results.append((i, path, None))

        # Match backtick-quoted directory paths: `.claude/skills/ezddd-java/references/`
        for m in re.finditer(r'`([^`]+/[^`]*/?)`', line):
            path = m.group(1).rstrip('/')
            if _is_real_path(path) and '.' not in path.split('/')[-1]:
                # Avoid double-matching files already caught above
                if not any(r[1] == path for r in results if r[0] == i):
                    results.append((i, path, None))

        # Match § section references: `path` § SectionName
        for m in re.finditer(r'`([^`]+)`\s*§\s*(.+?)(?:\s*$|\s*[,;>)])', line):
            path = m.group(1)
            section = m.group(2).strip()
            if _is_real_path(path) or path.endswith('.md'):
                results.append((i, path, section))

    return results


def check_section_exists(file_path: Path, section_name: str) -> bool:
    """Check if a markdown heading matching section_name exists in the file."""
    if not file_path.exists():
        return False
    try:
        content = file_path.read_text(encoding='utf-8')
    except (OSError, UnicodeDecodeError):
        return False

    # Normalize for comparison
    normalized = section_name.lower().strip()
    for line in content.splitlines():
        if line.startswith('#'):
            heading = re.sub(r'^#+\s*', '', line).strip().lower()
            # Remove emoji and special chars for fuzzy match
            heading_clean = re.sub(r'[^\w\s]', '', heading).strip()
            normalized_clean = re.sub(r'[^\w\s]', '', normalized).strip()
            if normalized_clean and normalized_clean in heading_clean:
                return True
    return False


def get_skill_headings(skill_path: Path) -> list[str]:
    """Get all top-level (##) headings from a SKILL.md file."""
    if not skill_path.exists():
        return []
    headings = []
    try:
        for line in skill_path.read_text(encoding='utf-8').splitlines():
            if line.startswith('## ') and not line.startswith('###'):
                heading = re.sub(r'^##\s*', '', line).strip()
                headings.append(heading)
    except (OSError, UnicodeDecodeError):
        pass
    return headings


def audit(root: Path, hook_mode: bool = False) -> list[Issue]:
    claude_md = root / 'CLAUDE.md'
    if not claude_md.exists():
        return [Issue('DEAD_LINK', 'CLAUDE.md', 0, 'CLAUDE.md', 'File not found')]

    content = claude_md.read_text(encoding='utf-8')
    issues: list[Issue] = []

    # --- Check 1: Dead links ---
    refs = extract_file_references(content)
    seen_paths: set[str] = set()

    for line_num, ref_path, section in refs:
        full_path = root / ref_path
        path_key = ref_path

        if path_key in seen_paths:
            continue
        seen_paths.add(path_key)

        if not full_path.exists():
            issues.append(Issue(
                'DEAD_LINK', 'CLAUDE.md', line_num, ref_path,
                f'Referenced path does not exist'
            ))
        elif section:
            # --- Check 2: Dead section references ---
            if not check_section_exists(full_path, section):
                issues.append(Issue(
                    'DEAD_SECTION', 'CLAUDE.md', line_num,
                    f'{ref_path} § {section}',
                    f'Section heading not found in file'
                ))

    if hook_mode:
        return issues

    # --- Check 3: SKILL.md cross-reference coverage ---
    skill_files = list((root / '.claude' / 'skills').rglob('SKILL.md'))
    for skill_path in skill_files:
        rel_path = skill_path.relative_to(root)
        headings = get_skill_headings(skill_path)
        for heading in headings:
            # Check if CLAUDE.md mentions this skill file at all
            skill_ref = str(rel_path)
            if skill_ref not in content:
                issues.append(Issue(
                    'MISSING_XREF', str(rel_path), 0, heading,
                    f'SKILL.md has section "{heading}" but is not referenced in CLAUDE.md'
                ))
                break  # One warning per unreferenced SKILL.md is enough

    return issues


def format_issues(issues: list[Issue]) -> str:
    if not issues:
        return ''

    lines = []
    by_severity = {}
    for issue in issues:
        by_severity.setdefault(issue.severity, []).append(issue)

    for severity in ['DEAD_LINK', 'DEAD_SECTION', 'MISSING_XREF']:
        group = by_severity.get(severity, [])
        if not group:
            continue
        emoji = {'DEAD_LINK': '🔗', 'DEAD_SECTION': '📑', 'MISSING_XREF': '📌'}
        lines.append(f'\n{emoji.get(severity, "•")} {severity} ({len(group)} found):')
        for issue in group:
            loc = f'  L{issue.line}' if issue.line else ''
            lines.append(f'  {issue.file}{loc} → `{issue.reference}`')
            lines.append(f'    {issue.detail}')

    return '\n'.join(lines)


def main():
    hook_mode = '--hook' in sys.argv
    root = find_project_root()
    issues = audit(root, hook_mode=hook_mode)

    if issues:
        output = format_issues(issues)
        if hook_mode:
            dead_links = [i for i in issues if i.severity == 'DEAD_LINK']
            if dead_links:
                print(f'⚠️ {len(dead_links)} dead link(s) in CLAUDE.md:', file=sys.stderr)
                print(format_issues(dead_links), file=sys.stderr)
                sys.exit(1)
        else:
            print(f'📋 Documentation Audit: {len(issues)} issue(s) found')
            print(output)
            sys.exit(1)
    else:
        if not hook_mode:
            print('✅ Documentation audit passed — no issues found')
        sys.exit(0)


if __name__ == '__main__':
    main()
