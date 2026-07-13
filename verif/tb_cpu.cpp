// Testbench harness for the single-cycle RV32I core.

// The stimulus is the program in instr_mem.hex,

#include <cstdio>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vcpu_single_cycle_top.h"
#include "Vcpu_single_cycle_top___024root.h"  // needed to reach inside the model

// A runaway branch (or a PC that never advances) will spin forever, because
// next_pc closes a combinational loop back to the PC. Bound it.
static const int MAX_CYCLES = 1000;

static VerilatedContext* ctx = nullptr;
static Vcpu_single_cycle_top* dut = nullptr;
static VerilatedVcdC* trace = nullptr;


//read regfile function
static uint32_t read_reg(int i) {
    return dut->rootp->cpu_single_cycle_top__DOT__reg_file_i__DOT__regs[i];
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
}


//main function
int main(int argc, char** argv) {
    int exit_code = 0;

    //set up context
    ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    ctx->traceEverOn(true);

    //instatiate DUT cpp model
    dut = new Vcpu_single_cycle_top{ctx};

    //start tracing
    trace = new VerilatedVcdC;
    dut->trace(trace, 99);
    trace->open("dump.vcd");

    reset();

    //Run loop
    int cycles = 0;
    while (cycles < MAX_CYCLES) {
        tick();
        cycles++;
    if (dut->halt) break;
    }

    //report type of end behavior, timeout is an error, halt could be success
    if(dut->halt) {
        printf("Halted after %d cycles\n", cycles);
    } else {
        printf("ERROR - TIMED OUT after %d cycles\n", cycles);
        exit_code = 1;
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
