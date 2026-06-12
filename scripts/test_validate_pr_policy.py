#!/usr/bin/env python3
"""Regression checks for validate_pr_policy.py."""

from __future__ import annotations

import importlib.util
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("validate_pr_policy.py")
spec = importlib.util.spec_from_file_location("validate_pr_policy", SCRIPT_PATH)
assert spec is not None
validate_pr_policy = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(validate_pr_policy)


def main() -> int:
    body = "\ufeff## Summary\nFixes a policy edge case.\n\n## Changes\n- Accept BOM-prefixed bodies.\n\n## Testing\n- python scripts/test_validate_pr_policy.py\n"
    errors = validate_pr_policy.validate_pull_request("fix(ci): accept bom headings", body)
    if errors:
        raise AssertionError(f"BOM-prefixed headings should validate, got: {errors}")

    title_errors = validate_pr_policy.validate_pull_request("\ufefffix(ci): accept bom title", body)
    if title_errors:
        raise AssertionError(f"BOM-prefixed titles should validate, got: {title_errors}")

    missing = validate_pr_policy.validate_pull_request("fix(ci): reject missing section", "## Summary\nOnly summary.\n")
    if not any("## Changes" in error for error in missing):
        raise AssertionError(f"Missing Changes section should be rejected, got: {missing}")

    print("validate_pr_policy regression tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
