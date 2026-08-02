# Acceptance criteria: forwarding-predicate-refactor

Task: name the duplicated MEM/WB forwarding sub-predicates in `design/cpu_core.sv`
as `mem_fwd_ok` / `wb_fwd_ok` and rewrite the four forwarding conditions in terms
of them. Claimed to be a pure subexpression-naming refactor with zero behavioural
change.

The burden of proof here is *equivalence*, not *correctness*. A passing regression
alone does not discharge it — the regression passed before the change too. Criteria
C1-C3 are structural (did the refactor actually happen as specified), C4-C8 are
equivalence evidence, C9 is the one that proves the critical x0 constraint is
actually load-bearing and actually tested rather than merely present in the source.

## Baseline (must be captured BEFORE any edit to cpu_core.sv)

    git stash list  # ensure tree is at pre-change HEAD
    for p in none btfn 2bit gshare; do make -s diffall PREDICTOR=$p; done
    mkdir -p /tmp/fwd-baseline && \
      for d in verif/sim/runs/diff_*_pipe verif/sim/runs/diff_*_sc; do \
        mkdir -p /tmp/fwd-baseline/$(basename $d); \
        cp $d/retire.log /tmp/fwd-baseline/$(basename $d)/; done
    make formal-status | tee /tmp/fwd-baseline/formal-status.txt

If no pre-change baseline was captured, C5 and C8 are UNVERIFIED by construction —
they cannot be reconstructed after the fact.

## Criteria

| ID | Criterion | Concrete check | Status |
|----|-----------|----------------|--------|
| C1 | Both intermediate signals exist and are declared, not implicit | `grep -nE '^\s*(logic\|wire)\b.*\b(mem_fwd_ok\|wb_fwd_ok)\b' design/cpu_core.sv` returns 2 declarations (or one declaration line covering both) | **PASS** |
| C2 | The WB sub-predicate is no longer duplicated inline: `wb_fwd_ok` is defined from the existing named signal `wb_reg_write`, not from a re-spelled copy | `grep -n 'mem_wb_q.valid && mem_wb_q.ctrl.reg_write' design/cpu_core.sv` returns **zero** hits, AND `grep -n 'assign wb_fwd_ok' design/cpu_core.sv` shows an expression containing the token `wb_reg_write` | **PASS** (see note) |
| C3 | The four forwarding conditions are expressed via the new signals and retain per-operand `uses_rs1`/`uses_rs2` and MEM-over-WB priority | `grep -nE 'assign ex_rs(1\|2)' -A2 design/cpu_core.sv` shows, for each of ex_rs1 and ex_rs2: `mem_fwd_ok` term first (selecting `mem_alu_result`), `wb_fwd_ok` term second (selecting `wb_rd_data`), fallback `id_ex_q.rs1_data`/`rs2_data`; each ex_rs1 term contains `uses_rs1`, each ex_rs2 term contains `uses_rs2`; rd_addr comparison against the matching `rs1_addr`/`rs2_addr` | **PASS** |
| C4 | **CRITICAL CONSTRAINT — x0 guard re-added in wb_fwd_ok.** `wb_reg_write` omits the rd!=x0 guard (reg_file.sv handles x0 internally); forwarding has no such guard | `grep -n 'assign wb_fwd_ok' design/cpu_core.sv` shows a term matching `mem_wb_q.rd_addr != 5'd0` (or `!= '0`). Absence of this term is an automatic FAIL of the whole task regardless of every other criterion | **PASS** |
| C5 | The mem-side x0 guard survived the refactor | `grep -n 'assign mem_fwd_ok' design/cpu_core.sv` shows terms for `ex_mem_q.valid`, `ex_mem_q.ctrl.reg_write`, `!ex_mem_q.trap`, and `ex_mem_q.rd_addr != 5'd0` | **PASS** |
| C6 | No new lint warnings; new signals are used, not dangling | `make lint` exits 0 with no `%Warning` lines. Specifically no `UNUSEDSIGNAL`/`UNDRIVEN` naming `mem_fwd_ok` or `wb_fwd_ok`, and no `UNOPTFLAT`/`LATCH` in cpu_core | **PASS** (see note) |
| C7 | Retirement-stream equivalence vs the single-cycle golden model holds for every predictor | `make diffall PREDICTOR=none`, `=btfn`, `=2bit`, `=gshare` each print `DIFF OK` for all 12 DIFF_PROGS (smoke alu branch lui_auipc mem jump x0 hazards arraysum bubblesort search statemachine) and zero `DIFF FAIL` lines | **PASS** |
| C8 | **Bit-identical retirement streams, not merely "still passing".** A pure refactor must leave every retire.log byte-for-byte unchanged | After running C7: `for d in verif/sim/runs/diff_*_pipe; do cmp $d/retire.log /tmp/fwd-baseline/$(basename $d)/retire.log \|\| echo MISMATCH $d; done` prints nothing. Any `MISMATCH` line = FAIL (a behavioural change occurred). Note: the runs dir holds only the last predictor's pipe logs, so this comparison must be done per-predictor immediately after each `diffall`, or baseline+post dirs kept per predictor | **PASS** |
| C9 | **The x0 guard is proven load-bearing, not just present.** Mutation check: with the `rd_addr != 5'd0` term deliberately deleted from `wb_fwd_ok`, at least one named check must FAIL | Delete the term, then run `make diffall PREDICTOR=none` and `make formal-gen && make formal-run CHECK=reg_ch0/status && make formal-status`. Evidence required: a `DIFF FAIL` line, and/or `reg_ch0` reported as FAIL by `verif/formal/status.py`. Then restore the term and re-confirm C7/C8. If **no** check fails under mutation, record that fact — the guard is correct but untested, and C9 is FAIL (the criterion is about test coverage, not about the RTL) | **PASS** |
| C10 | Official ISA suite still fully passes on the pipeline for every predictor | `make regress TOP=cpu_pipeline_top PREDICTOR=<none\|btfn\|2bit\|gshare>` each print `rv32ui: N passed, 0 failed` with the same N as the pre-change run (excluded: ma_data fence_i) | **PASS** |
| C11 | Formal verdicts unchanged | `make formal-gen && make formal-run && make formal-status` tally line is identical to `/tmp/fwd-baseline/formal-status.txt`, with zero `FAIL`, zero `ERROR`, zero `CANCELLED`, and an empty `FAILING CHECKS` section | **PASS** |
| C12 | Formal is non-vacuous (otherwise C11 proves nothing) | `make formal-cover` reports PASS for `cover.sby` (`cnt_insns >= 2` reachable) | **PASS** |
| C13 | The bound x0 invariants on cpu_core's source-operand paths still hold | In the C11 run, no failure is reported at `invariants.sv:47-56` (the `if (*_rs1_addr == 5'd0) assert (*_rs1_rdata == 32'd0)` block) — this is the assertion that fires if an x0-targeted result is forwarded as a source operand, *provided* the RVFI rs1/rs2 rdata taps carry the post-forwarding operand | **PASS** (bounded) |
| C14 | Blast radius: only the intended file changed | `git diff --stat` lists `design/cpu_core.sv` and nothing else under `design/`. In particular `design/cpu_single_cycle_top.sv` (the golden reference for C7/C8) is untouched — a matching change on both sides of an equivalence check would mask a bug | **FAIL** |
| C15 | Diff is confined to the forwarding block | `git diff design/cpu_core.sv` touches only the ex_rs1/ex_rs2 assign block (~lines 251-259) plus the new declarations/assigns for `mem_fwd_ok`/`wb_fwd_ok`. No reflowed formatting, no renamed signals, no changes to `wb_reg_write` (line ~474) or the reg-file write-enable use (line ~208) | **PASS** |

## Notes on coverage limits (read before marking anything PASS)

- **`tests.yaml` `x0` test `not_covered`: "x0 as source in complex addressing modes."**
  The `x0` diff program proves writes to x0 are silent at the architectural level.
  It is **not** documented as covering the specific sequence this refactor could
  break — an instruction with `rd = x0` followed two slots later by a consumer
  reading x0. Therefore C7/C8 passing does **not** by itself discharge C4. C9 is
  the criterion that does. If C9 was not run, C4 is structural-only (grep) and the
  behavioural claim behind it is UNVERIFIED.
- **`tests.yaml` `hazards` test `not_covered`: "load-to-use stalls", "multi-cycle
  dependencies."** Do not read a `DIFF OK` on `hazards` as evidence that stall
  interaction with the new predicates is covered. This refactor does not touch
  stall logic, so that gap is acceptable — but it must not be cited as coverage.
- The formal run is `mode bmc` at depth 15 (insn) / 16 (reg). C11/C13 are
  *bounded* evidence. A verdict of PASS means "no counterexample within the
  bound", not an unbounded proof. Mark PASS, but do not upgrade the claim.
- `reg_ch0` (C9) works because RVFI requires `rvfi_rd_wdata == 0` when
  `rvfi_rd_addr == 0`, so the checker's shadow for register_index 0 is 0; a
  forwarded x0 result would make `rvfi_rs1_rdata` nonzero for an x0 source and
  trip `rvfi_reg_check.sv:42`. This only holds if the mutation is actually
  visible on the RVFI rs1/rs2 rdata taps.

## Out of scope

- **Formal sequential-equivalence proof (pre-netlist vs post-netlist) via Yosys
  `equiv_make`/`equiv_induct`.** This would be the definitive discharge of "zero
  behavioural change" and would subsume C7/C8/C11 — but there is no make target
  for it and the repo's Yosys use is `lint-synth` (area/timing sanity) only.
  Standing it up is a larger job than the refactor. Listed here rather than as a
  criterion because an unrun check must not be dressed up as a passing one.
- **Timing/area impact.** Naming a subexpression should be synthesis-neutral, but
  the repo has no timing-closure or area-regression gate, so there is no check to
  name. Not verifiable.
- **Whether the *existing* forwarding logic is architecturally correct** (e.g.
  load-use interaction, trap-flush timing). Out of scope by definition: the task
  asserts equivalence to the current behaviour, so a pre-existing bug is
  faithfully preserved and both sides of every equivalence check agree. If a
  reviewer suspects such a bug, it is a separate task with separate criteria.
- **`make stats` CPI/flush numbers.** Should be unchanged, but these are
  performance counters with no pass/fail gate; a delta would be interesting, not
  disqualifying.

## Verdict (verify mode, independently re-run)

14 PASS / 1 FAIL / 0 UNVERIFIED. Every named check was re-executed against the
working tree by the judge; no criterion was marked from the implementation
report alone.

- **C14 FAIL.** `git diff --stat` lists 9 files, 4 of them under `design/` with
  non-whitespace changes counted, and `design/src/reg_file.sv` carries a real
  source change (`parameter P_ENABLE_BYPASS = 1` -> `parameter bit ...`). The
  criterion as written ("`design/cpu_core.sv` and nothing else under
  `design/`") is not satisfied. The *anti-masking* sub-clause that motivates
  C14 **is** satisfied and was verified separately:
  `git diff --ignore-all-space -- design/cpu_single_cycle_top.sv` is empty, so
  the golden reference for C7/C8 is functionally untouched and the equivalence
  check is not self-confirming. Verdict is FAIL on blast radius, not on
  masking.
- **C2 note.** Literal grep for `mem_wb_q.valid && mem_wb_q.ctrl.reg_write`
  returns 1 hit, at line 486 -- the canonical `assign wb_reg_write` definition,
  which is the signal C2's second clause requires `wb_fwd_ok` to be built from.
  The grep's zero-hit expectation was written on a false premise about how that
  definition is spelled. No inline duplicate exists in the forwarding block.
  Intent governs; marked PASS.
- **C6 note.** Verilator `-Wall +define+RVFI` is clean (0 `%Warning`/`%Error`,
  exit 0) -- the four specifically named classes (UNUSEDSIGNAL, UNDRIVEN,
  UNOPTFLAT, LATCH) are all verilator's and are all verified. The verible half
  of `make lint` is clean only because this same diff adds
  `.rules.verible_lint` (untracked) disabling `line-length`, and changes the
  Makefile to `--rules_config_search`. Running verible without it still reports
  `line-length` on the refactored lines 265-269 (142-158 chars). Not a new
  defect -- the pre-change lines were longer -- but the verible side of "no new
  lint warnings" rests on a waiver introduced in the same diff, not on the code.
- **C9 reproduced independently.** The judge re-ran the mutation in an isolated
  copy of the tree (no project RTL touched). Deleting the x0 term reproduced
  exactly: `DIFF FAIL x0`, `DIFF FAIL hazards`, `rv32ui: 24 passed, 16 failed`,
  and `reg_ch0` FAIL at `verif/formal/invariants.sv:55.34-55.69 step 16`.
- **C13** upgraded from conditional to PASS: the C9 mutation firing at
  invariants.sv:55 empirically establishes that the RVFI rs2 rdata tap carries
  the post-forwarding operand, which was the stated proviso. Bounded (bmc
  depth 16), as noted.
- **C10** pre-change N established independently, not taken from the report: a
  HEAD-version copy of `cpu_core.sv` also yields `rv32ui: 40 passed, 0 failed`.
- **C8** verified per-predictor immediately after each `diffall`: all 48
  retire.log files byte-identical to `/tmp/fwd-baseline/<pred>/`.
