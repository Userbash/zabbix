#!/usr/bin/env python3
"""Analyze container logs and produce JSON/Markdown reports.

Requires (optional): rich, python-dateutil
"""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone

try:
    from rich.console import Console
    from rich.table import Table
except Exception:
    Console = None
    Table = None

ERROR_PATTERNS = [
    ("critical", re.compile(r"out of memory|oom-kill|oom killer|killed process|cannot allocate", re.I)),
    ("high", re.compile(r"fatal|panic|segfault|core dumped", re.I)),
    ("high", re.compile(r"failed to start|startup.*failed", re.I)),
    ("high", re.compile(r"connection refused|connection reset|no such host", re.I)),
    ("high", re.compile(r"^(E:|Err:)\s|unlockpt \(22: Invalid argument\)", re.I)),
    ("medium", re.compile(r"\b(error|exception)\b", re.I)),
    ("low", re.compile(r"\b(warn|warning)\b", re.I)),
]

SUMMARY = {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
}


def scan_file(path: str) -> list[dict]:
    findings: list[dict] = []
    try:
        with open(path, "r", errors="ignore") as handle:
            for idx, line in enumerate(handle, 1):
                for severity, pattern in ERROR_PATTERNS:
                    if pattern.search(line):
                        findings.append(
                            {
                                "file": os.path.basename(path),
                                "line": idx,
                                "severity": severity,
                                "message": line.strip()[:300],
                            }
                        )
                        SUMMARY[severity] += 1
                        break
    except FileNotFoundError:
        return findings
    return findings


def write_reports(out_dir: str, findings: list[dict]) -> None:
    ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    json_path = os.path.join(out_dir, "analysis.json")
    md_path = os.path.join(out_dir, "analysis.md")

    with open(json_path, "w") as handle:
        json.dump({"timestamp": ts, "summary": SUMMARY, "findings": findings}, handle, indent=2)

    with open(md_path, "w") as handle:
        handle.write("# Container Log Analysis\n\n")
        handle.write(f"Timestamp: {ts}\n\n")
        handle.write("## Summary\n\n")
        for key in ("critical", "high", "medium", "low"):
            handle.write(f"- {key}: {SUMMARY[key]}\n")
        handle.write("\n## Findings\n\n")
        for item in findings[:200]:
            handle.write(
                f"- [{item['severity']}] {item['file']}:{item['line']} - {item['message']}\n"
            )


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: log-analyzer.py <run-dir>")
        return 1

    run_dir = sys.argv[1]
    logs_dir = os.path.join(run_dir, "logs")
    if not os.path.isdir(logs_dir):
        print(f"Missing logs directory: {logs_dir}")
        return 1

    findings: list[dict] = []
    for name in sorted(os.listdir(logs_dir)):
        if name.endswith(".log"):
            findings.extend(scan_file(os.path.join(logs_dir, name)))

    write_reports(run_dir, findings)

    if Console and Table:
        console = Console()
        table = Table(title="Log Analysis Summary")
        table.add_column("Severity")
        table.add_column("Count", justify="right")
        for key in ("critical", "high", "medium", "low"):
            table.add_row(key, str(SUMMARY[key]))
        console.print(table)
    else:
        print("Summary:")
        for key in ("critical", "high", "medium", "low"):
            print(f"  {key}: {SUMMARY[key]}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
