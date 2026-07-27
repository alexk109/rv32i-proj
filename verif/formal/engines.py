#!/usr/bin/env python3
"""Rewrite generated .sby files to race several engines under a timeout.

genchecks.py hardcodes a single engine and no timeout, so this patches its
output afterwards. sby runs everything in [engines] concurrently and takes the
first conclusive answer -- useful because smtbmc (k-induction) and abc pdr
(IC3) have different strengths and it's not predictable which wins on a given
property.

Usage: engines.py <checks-dir> [--timeout N] [--engines "a;b;c"]
"""

import argparse
import re
import sys
from pathlib import Path

DEFAULT_ENGINES = ["smtbmc yices", "smtbmc z3", "abc pdr"]


def rewrite(path: Path, engines: list[str], timeout: int | None) -> None:
    text = path.read_text()

    # `skip` is rejected by every engine except smtbmc/btor, and in prove mode it
    # is meaningless anyway: RISCV_FORMAL_UNBOUNDED makes the checker's `check`
    # input a free variable, so there is no single cycle to skip to.
    if re.search(r"^mode\s+prove\s*$", text, re.M):
        text = re.sub(r"^skip\s+\d+\s*\n", "", text, flags=re.M)

    # Replace the whole [engines] stanza (up to the next section or blank-line gap).
    new_block = "[engines]\n" + "\n".join(engines) + "\n"
    text = re.sub(r"\[engines\]\n(?:[^\[\n][^\n]*\n)*", new_block, text, count=1)

    if timeout is not None and "\ntimeout " not in text:
        # sby wants `timeout` inside [options]; put it right after the header.
        text = text.replace("[options]\n", f"[options]\ntimeout {timeout}\n", 1)

    path.write_text(text)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("checks_dir")
    ap.add_argument("--timeout", type=int, default=None)
    ap.add_argument("--engines", default=";".join(DEFAULT_ENGINES),
                    help="semicolon-separated engine lines")
    args = ap.parse_args()

    d = Path(args.checks_dir)
    if not d.is_dir():
        print(f"no checks directory at {d}", file=sys.stderr)
        return 1

    engines = [e.strip() for e in args.engines.split(";") if e.strip()]
    sbys = sorted(d.glob("*.sby"))
    for f in sbys:
        rewrite(f, engines, args.timeout)

    print(f"patched {len(sbys)} .sby files")
    print(f"  engines: {', '.join(engines)}")
    print(f"  timeout: {args.timeout if args.timeout else 'none'}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
