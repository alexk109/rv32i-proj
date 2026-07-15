# Branch Predictor Results

CPI and misprediction rate across the benchmark suite, one row per predictor
scheme. Regenerate a row with `make run TOP=cpu_pipeline_top PROG=<b>` and read
the `--- perf ---` block.

**Aggregate CPI** = total cycles / total instructions across the suite (a rate
must be pooled, not arithmetic-averaged — a small program must not weigh the same
as a large one). **Aggregate mispredict** = total mispredicted / total branches.

All schemes must keep `make diffall` green: prediction changes speed, never
correctness. A misprediction only triggers the flush the pipeline already has.

## CPI (lower is better)

| predictor          | bubblesort | search | statemachine | arraysum | **aggregate** |
|--------------------|-----------:|-------:|-------------:|---------:|--------------:|
| none (not-taken)   |      1.660 |  1.454 |        1.413 |    1.493 |     **1.464** |
| static BTFN        |            |        |              |          |               |
| 2-bit bimodal +BTB |            |        |              |          |               |
| gshare +BTB        |            |        |              |          |               |
| gshare +BTB +RAS   |            |        |              |          |               |

## Misprediction rate (lower is better)

| predictor          | bubblesort | search | statemachine | **aggregate** |
|--------------------|-----------:|-------:|-------------:|--------------:|
| none (not-taken)   |      75.9% |  50.0% |        79.7% |     **70.5%** |
| static BTFN        |            |        |              |               |
| 2-bit bimodal +BTB |            |        |              |               |
| gshare +BTB        |            |        |              |               |
| gshare +BTB +RAS   |            |        |              |               |

## Notes on what each benchmark reveals

- **bubblesort** — loop-heavy plus one ~50/50 data-dependent swap branch. Great
  for "prediction vs none"; the swap branch is near-unpredictable for everyone.
- **search** — early-exit loops, sits at exactly 50% under not-taken. A bimodal
  predictor should pull this down hard by nailing the loop branches.
- **statemachine** — correlated control flow: the next outcome depends on branch
  history. This is the workload where **gshare should beat plain bimodal** — if
  it doesn't, the global-history indexing is not doing its job.

## Baseline observation

Under predict-not-taken the whole suite is control-hazard bound: ~70% of branches
mispredict, and each costs 2 flushed instructions. That is the CPI headroom the
predictor is going after — aggregate 1.464 toward an ideal near 1.05.
