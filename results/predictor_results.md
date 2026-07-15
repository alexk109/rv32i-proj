# Branch Predictor Results

CPI and control-hazard cost across the branch-heavy benchmark suite, one row per
predictor. Regenerate with `make run TOP=cpu_pipeline_top PREDICTOR=<p> PROG=<b>`
and read the `--- perf ---` block; correctness with `make verify`.

**Aggregate** = pooled over the suite (total cycles / total instructions — a rate
must be pooled, not arithmetic-averaged). **flush/instr** = flush cycles per
retired instruction (from `perf_flush`): the per-instruction cost of control
hazards, which is what a predictor exists to shrink.

Every scheme keeps `make verify` green: prediction changes speed, never
architectural results.

## CPI (lower is better)

| predictor          | bubblesort | search | statemachine | **aggregate** |
|--------------------|-----------:|-------:|-------------:|--------------:|
| none (not-taken)   |      1.660 |  1.454 |        1.413 |     **1.463** |
| btfn (static)      |      1.337 |  1.009 |        1.167 |     **1.165** |
| 2bit bimodal (PHT) |      1.256 |  1.011 |        1.070 |     **1.090** |

## flush cycles per instruction (control-hazard cost, lower is better)

| predictor          | bubblesort | search | statemachine | **aggregate** |
|--------------------|-----------:|-------:|-------------:|--------------:|
| none (not-taken)   |      0.254 |  0.227 |        0.206 |     **0.219** |
| btfn (static)      |      0.092 |  0.004 |        0.084 |     **0.069** |
| 2bit bimodal (PHT) |      0.052 |  0.005 |        0.035 |     **0.032** |

## Headline

CPI **1.463 → 1.090** and control-hazard flushes **0.219 → 0.032 per instruction
(−85%)**, going from no prediction to a bimodal (per-PC 2-bit) predictor on a
5-stage RV32I pipeline.

## Findings

**btfn — static BTFN.** Big jump over none (CPI 1.463 → 1.165) with zero state.
Shines on loop-dominated code — `search` hits CPI 1.009 because its loops are
backward branches BTFN predicts perfectly. Computes targets directly from the
fetched instruction; no BTB.

**2bit bimodal — a Pattern History Table indexed by PC.** Best overall (1.090),
beating btfn everywhere it matters:
- **bubblesort** 1.256 vs 1.337 — the per-PC counters learn the data-dependent
  swap branch's bias, which btfn's crude sign heuristic can't.
- **statemachine** 1.070 vs 1.167 — correlated control flow; per-PC counters
  capture each branch's mode.
- **search** ties btfn (~1.01) — both nail its highly-biased branches.

The path from broken to best is the whole lesson: the first 2bit used a *single
global counter*, which (a) predicted taken for every instruction until the
branch-type gate was added (a correctness bug caught only by the benchmark diff,
after a harness bug that swallowed it was fixed), and (b) let unrelated branches
destructively share two bits — worse than btfn on `search` (CPI 1.438). Splitting
it into a per-PC table removed both: `search` recovered to 1.011 and the
aggregate dropped below btfn.

## Next

- **gshare** — index the PHT with `pc XOR global_history`. Expected to beat
  bimodal specifically on `statemachine`, whose branches are correlated (the next
  outcome depends on branch history, which a per-PC-only counter cannot see).
- **BTB + RAS** — needed for JALR targets (currently unpredictable) and for
  correctly-predicted returns.
- Table-size sweep (a `parameter` in the PHT) for a sensitivity row.
