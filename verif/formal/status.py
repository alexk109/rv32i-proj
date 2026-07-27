#!/usr/bin/env python3
"""Summarize a riscv-formal check run.

sby leaves a one-line `status` file (`<verdict> <retcode> <seconds>`) and a
summary file named after the verdict, holding the failed assertion and trace
paths. This reads both, resolves each failure back to its source line, and
groups checks by the property that broke.

Usage: status.py <checks-dir> [-v]
"""

import re
import sys
from collections import defaultdict
from pathlib import Path

VERDICTS = ("PASS", "FAIL", "UNKNOWN", "ERROR", "TIMEOUT", "CANCELLED")

# "... at rvfi_insn_check.sv:177.7-177.40 step 15"
ASSERT_RE = re.compile(r"at (\S+?):(\d+)\.\d+-\d+\.\d+(?: step (\d+))?")


def source_line(check_dir: Path, filename: str, lineno: int) -> str:
    """The actual assert text, read from the check's own copy of the sources."""
    src = check_dir / "src" / filename
    if not src.is_file():
        return ""
    try:
        return src.read_text().splitlines()[lineno - 1].strip()
    except (IndexError, OSError):
        return ""


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    verbose = "-v" in sys.argv[1:]
    if not args:
        print("usage: status.py <checks-dir> [-v]", file=sys.stderr)
        return 2

    checks = Path(args[0])
    if not checks.is_dir():
        print(f"no checks directory at {checks} -- run 'make formal-gen' first",
              file=sys.stderr)
        return 1

    rows, running = [], []
    for d in sorted(p for p in checks.iterdir() if p.is_dir()):
        status_file = d / "status"
        if not status_file.is_file():
            running.append(d.name)
            continue
        parts = status_file.read_text().split()
        verdict = parts[0] if parts else "?"
        retcode = parts[1] if len(parts) > 1 else "?"
        secs = parts[2] if len(parts) > 2 else "?"
        rows.append((d.name, verdict, retcode, secs, d))

    counts = defaultdict(int)
    for _, v, *_ in rows:
        counts[v] += 1
    for r in running:
        counts["RUNNING"] += 1

    print(f"\n=== riscv-formal: {checks.parent.name} ===\n")
    tally = "   ".join(f"{v} {counts[v]}" for v in
                       list(VERDICTS) + ["RUNNING"] if counts[v])
    print(f"  {tally}\n")

    # Group failures by the assertion that broke.
    groups = defaultdict(list)
    for name, verdict, retcode, secs, d in rows:
        if verdict == "PASS":
            continue
        summary = d / verdict
        where, step, text = "?", "?", ""
        if summary.is_file():
            for line in summary.read_text().splitlines():
                m = ASSERT_RE.search(line)
                if m:
                    where = f"{m.group(1)}:{m.group(2)}"
                    step = m.group(3) or "?"
                    text = source_line(d, m.group(1), int(m.group(2)))
                    break
        groups[(where, text)].append((name, verdict, secs, d, step))

    if groups:
        print("FAILING CHECKS\n")
        for (where, text), items in sorted(groups.items(),
                                           key=lambda kv: -len(kv[1])):
            print(f"  {where}   ({len(items)} check{'s' if len(items) > 1 else ''})")
            if text:
                print(f"      {text}")
            for name, verdict, secs, d, step in sorted(items):
                print(f"        {verdict:5} {name:<20} step {step:<4} {secs}s")
            trace = items[0][3] / "engine_0" / "trace.vcd"
            if trace.is_file():
                print(f"      trace: {trace}")
            print()

    if running:
        print("STILL RUNNING\n")
        for name in running:
            print(f"  {name}")
        print()

    if verbose:
        print("ALL CHECKS\n")
        for name, verdict, retcode, secs, _ in rows:
            print(f"  {verdict:5} {name:<24} {secs:>4}s  (rc={retcode})")
        print()

    # ERROR/CANCELLED mean the tool itself broke (build failure, crash), not
    # that a property failed -- distinct from UNKNOWN (induction couldn't
    # decide) or TIMEOUT (ran out of time), both normal outcomes to report as-is.
    broken = [n for n, v, _, _, _ in rows if v in ("ERROR", "CANCELLED")]
    if broken:
        print("TOOL ERRORS (these did not produce a real result)\n")
        for n in broken:
            print(f"  {n}")
        print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
