// Testbench harness for the single-cycle RV32I core.

// The stimulus is the program in instr_mem.hex,

#include <cstdio>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>

// The same harness drives either top. Verilator names the generated class after
// the top module and mangles internal paths with __DOT__, so both have to be
// selected at compile time. The Makefile passes -DPIPELINE when TOP is the
// pipelined core.
#ifdef PIPELINE
  #include "Vcpu_pipeline_top.h"
  #include "Vcpu_pipeline_top___024root.h"
  typedef Vcpu_pipeline_top Vdut;
  #define DUT_REGS rootp->cpu_pipeline_top__DOT__reg_file_i__DOT__regs
#else
  #include "Vcpu_single_cycle_top.h"
  #include "Vcpu_single_cycle_top___024root.h"
  typedef Vcpu_single_cycle_top Vdut;
  #define DUT_REGS rootp->cpu_single_cycle_top__DOT__reg_file_i__DOT__regs
#endif

// A runaway branch (or a PC that never advances) will spin forever, because
// next_pc closes a combinational loop back to the PC. Bound it.
static const int MAX_CYCLES = 100000;

static VerilatedContext* ctx = nullptr;
static Vdut* dut = nullptr;
static VerilatedVcdC* trace = nullptr;


//read regfile function
static uint32_t read_reg(int i) {
    return dut->DUT_REGS[i];
}


//per clock edge tick function.
static void tick() {

    dut->clk   = 0;
    dut->eval();
    trace->dump(ctx->time());
    ctx->timeInc(1);
    
    dut->clk   = 1;
    dut->eval();
    trace->dump(ctx->time());
    ctx->timeInc(1);
}


//reset function. two ticks for safety
static void reset() {
    dut->rst_n = 0;
    tick();
    tick();
    dut->rst_n = 1;
    // Settle combinational logic with reset deasserted, so the first sampled cycle
    // sees the true post-reset state (single-cycle's rvfi_valid = rst_n needs this
    // eval to go high before the first sample).
    dut->eval();
}


//main function
int main(int argc, char** argv) {
    int exit_code = 0;

    //set up context
    ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    ctx->traceEverOn(true);

    //instatiate DUT cpp model
    dut = new Vdut{ctx};

    //start tracing
    trace = new VerilatedVcdC;
    dut->trace(trace, 99);
    trace->open("dump.vcd");

    reset();

    // Retirement log: one line per committed instruction, capturing its full
    // architectural effect (register write + memory write). Two cores running the
    // same program must produce identical logs regardless of pipeline timing, so
    // diffing pipeline against single-cycle is a golden-model equivalence check —
    // the same shape Spike co-simulation will take.
    FILE* retlog = fopen("retire.log", "w");

    // Performance counters. Everything except stall/flush is derived from the
    // RVFI retirement signals; stall/flush come from the two perf_ outputs.
    long cycles      = 0;   // every clock, until halt
    long retired     = 0;   // rvfi_valid — instructions that actually committed
    long stall_cyc   = 0;   // load-use bubbles
    long flush_cyc   = 0;   // control-hazard redirects
    long branches    = 0;   // conditional branches retired
    long taken       = 0;   // ...of which were taken (= mispredicts, predict-not-taken)

    // Sample the SETTLED state, then advance. Single-cycle's RVFI is combinational
    // (the instruction about to commit on the next edge); the pipeline's is
    // registered (the instruction that just committed). Sampling before the tick
    // gives both cores one clean record per retired instruction and aligns their
    // logs — sample-after-tick would drop single-cycle's first instruction.
    while (cycles < MAX_CYCLES) {
        cycles++;   // this iteration IS one cycle, including the halting cycle

        if (dut->perf_stall) stall_cyc++;
        if (dut->perf_flush) flush_cyc++;

        if (dut->rvfi_valid) {
            retired++;
            if ((dut->rvfi_insn & 0x7f) == 0x63) {   // BRANCH opcode
                branches++;
                // taken iff the next PC is not the sequential fall-through
                if (dut->rvfi_pc_wdata != dut->rvfi_pc_rdata + 4) taken++;
            }
            // Architectural effect only (pc / rd / mem), never timing — that's what
            // makes the two cores' streams comparable. The mem fields are don't-care
            // unless this is a store, and even then only the written byte lanes
            // matter, so mask them; otherwise harmless garbage in unwritten lanes
            // (rs2<<shift computed for every instruction) causes false mismatches.
            uint32_t wmask = dut->rvfi_mem_wmask;
            uint32_t bytemask = 0;
            for (int b = 0; b < 4; b++)
                if (wmask & (1u << b)) bytemask |= 0xffu << (8 * b);
            uint32_t eff_addr  = wmask ? dut->rvfi_mem_addr : 0;
            uint32_t eff_wdata = wmask ? (dut->rvfi_mem_wdata & bytemask) : 0;

            fprintf(retlog, "%08x %2u %08x %x %08x %08x\n",
                    dut->rvfi_pc_rdata, dut->rvfi_rd_addr, dut->rvfi_rd_wdata,
                    wmask, eff_addr, eff_wdata);
        }

        if (dut->halt) break;

        tick();
    }

    fclose(retlog);

    //report type of end behavior, timeout is an error, halt could be success
    if(dut->halt) {
        printf("Halted after %ld cycles\n", cycles);
    } else {
        printf("ERROR - TIMED OUT after %ld cycles\n", cycles);
        exit_code = 1;
    }

    // CPI and its decomposition. cycles = retired + bubbles, so CPI above 1.0 is
    // exactly the per-instruction cost of stalls and flushes.
    if (retired > 0) {
        printf("--- perf ---\n");
        printf("  cycles      %ld\n", cycles);
        printf("  retired     %ld\n", retired);
        printf("  CPI         %.3f\n", (double)cycles / retired);
        printf("  stall cyc   %ld  (%.3f/instr)\n", stall_cyc, (double)stall_cyc / retired);
        printf("  flush cyc   %ld  (%.3f/instr)\n", flush_cyc, (double)flush_cyc / retired);
        printf("  branches    %ld\n", branches);
        if (branches > 0)
            printf("  mispredict  %ld  (%.1f%%)  [baseline: predict not-taken]\n",
                   taken, 100.0 * taken / branches);
    }
    
    uint32_t gp = read_reg(3);
    uint32_t a0 = read_reg(10);

    //riscv-tests exit convention: a0 == 0 is pass. On failure a0 is (gp << 1) | 1
    //and gp still holds the number of the subtest that broke.
    if (dut->halt) {
        if (a0 == 0) {
            printf("PASS\n");
        } else {
            printf("FAIL - subtest %u\n", gp);
            exit_code = 1;
        }
    }

    dut->final();

    trace->close();
    delete trace;
    delete dut;
    delete ctx;

    return exit_code;
}
