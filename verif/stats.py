#!/usr/bin/env python3
"""Sweep every predictor x benchmark, collect perf, print the results tables.

Invoked by `make stats`. Shells out to `make run` for each (predictor, program),
parses the `--- perf ---` block, and prints CPI and flush/instr tables with a
pooled aggregate column. Pooled = sum(cycles)/sum(retired): a rate must be
weighted by instruction count, never arithmetic-averaged.
"""

import os
import re
import subprocess
import sys

PREDICTORS = sys.argv[1].split() if len(sys.argv) > 1 else ["none", "btfn", "2bit", "gshare"]
BENCHES    = sys.argv[2].split() if len(sys.argv) > 2 else ["bubblesort", "search", "statemachine"]

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(pred, prog):
    """Run one program on the pipeline with one predictor; return (cycles, retired, flush)."""
    out = subprocess.run(
        ["make", "-s", "run", "TOP=cpu_pipeline_top",
         f"PREDICTOR={pred}", f"PROG={prog}", f"RUN=stats_{pred}_{prog}"],
        cwd=ROOT, capture_output=True, text=True).stdout
    def grab(key):
        m = re.search(key + r"\s+([0-9]+)", out)
        return int(m.group(1)) if m else None
    return grab("cycles"), grab("retired"), grab(r"flush cyc")


# data[pred][prog] = (cpi, flush_per_instr); plus per-pred pooled aggregate
data, agg = {}, {}
for pred in PREDICTORS:
    subprocess.run(["make", "-s", "sim", "TOP=cpu_pipeline_top", f"PREDICTOR={pred}"],
                   cwd=ROOT, capture_output=True, text=True)
    tc = tr = tf = 0
    data[pred] = {}
    for prog in BENCHES:
        c, r, f = run(pred, prog)
        if r is None or r == 0:
            data[pred][prog] = None
            continue
        data[pred][prog] = (c / r, f / r)
        tc, tr, tf = tc + c, tr + r, tf + f
    agg[pred] = (tc / tr, tf / tr) if tr else None


def table(title, idx, fmt):
    hdr = "| predictor" + "".join(f" | {b}" for b in BENCHES) + " | **aggregate** |"
    sep = "|" + "-----------|" * (len(BENCHES) + 2)
    print(f"\n## {title}\n\n{hdr}\n{sep}")
    for pred in PREDICTORS:
        cells = []
        for prog in BENCHES:
            v = data[pred][prog]
            cells.append(fmt(v[idx]) if v else "FAIL")
        a = agg[pred]
        cells.append(f"**{fmt(a[idx])}**" if a else "**FAIL**")
        print(f"|  {pred}     |   " + "     |   ".join(cells) + " | ")


print(f"Benchmarks: {' '.join(BENCHES)}")
table("CPI (lower is better)", 0, lambda x: f"{x:.3f}")
table("flush cycles per instruction (control-hazard cost)", 1, lambda x: f"{x:.3f}")
