#!/usr/bin/env python3
"""Validate lightweight pull request title/body policy."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


TITLE_PATTERN = re.compile(
    r"^(feat|fix|docs|ci|chore|perf|refactor|test|build|hotfix)(\([a-z0-9._/-]+\))?!?: .+",
    re.IGNORECASE,
)
REQUIRED_SECTIONS = ("Summary", "Changes", "Testing")
SUBSTANTIVE_SECTIONS = ("Summary", "Testing")


def strip_leading_bom(value: str) -> str:
    return value.lstrip("\ufeff")


def validate_pull_request(title: str, body: str) -> list[str]:
    title = strip_leading_bom(title or "").strip()
    body = strip_leading_bom(body or "")
    errors: list[str] = []

    if not TITLE_PATTERN.match(title):
        errors.append("PR title must use Conventional Commits format, for example 'fix(scope): concise summary'.")

    for section in REQUIRED_SECTIONS:
        if section_match(body, section) is None:
            errors.append(f"PR body must include '## {section}'.")

    for section in SUBSTANTIVE_SECTIONS:
        if section_match(body, section) is not None and not has_substantive_content(body, section):
            errors.append(f"PR body section '## {section}' must include a concrete statement, not only template placeholders.")

    return errors


def section_match(body: str, section_name: str) -> re.Match[str] | None:
    pattern = re.compile(rf"^##\s+{re.escape(section_name)}\s*$", re.IGNORECASE | re.MULTILINE)
    return pattern.search(body)


def section_text(body: str, section_name: str) -> str:
    match = section_match(body, section_name)
    if match is None:
        return ""
    next_heading = re.search(r"^##\s+", body[match.end():], re.MULTILINE)
    end = match.end() + next_heading.start() if next_heading else len(body)
    return body[match.end():end]


def has_substantive_content(body: str, section_name: str) -> bool:
    text = re.sub(r"<!--.*?-->", "", section_text(body, section_name), flags=re.DOTALL)
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line == "-" or re.fullmatch(r"```.*", line):
            continue
        if line.startswith("# Example:") or "<Godot Editor Path>" in line:
            continue
        return True
    return False


def load_pull_request(path: Path) -> tuple[str, str]:
    with path.open("r", encoding="utf-8-sig") as fields_file:
        pull_request = json.load(fields_file)
    return pull_request.get("title") or "", pull_request.get("body") or ""


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fields-json", required=True, type=Path, help="JSON file containing title and body fields.")
    args = parser.parse_args(argv)

    title, body = load_pull_request(args.fields_json)
    errors = validate_pull_request(title, body)
    if errors:
        for error in errors:
            print(f"::error::{error}")
        return 1

    print("PR standards validated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
