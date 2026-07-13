#ifndef _ENV_SINGLECYCLE_H
#define _ENV_SINGLECYCLE_H

// Minimal bare-metal test environment for the single-cycle core.
//
// The stock riscv-tests "p" environment sets up trap vectors and touches
// mtvec/mstatus/mhartid. This core has no CSRs (Phase 3E), so that environment
// cannot run. Everything here is CSR-free.
//
// Exit convention, matching riscv-tests: a0 == 0 means pass. On failure a0 is
// (TESTNUM << 1) | 1, and gp still holds the number of the failing subtest.

#define TESTNUM gp

#define RVTEST_RV32U
#define RVTEST_RV64U
#define RVTEST_RV32M
#define RVTEST_RV64M

#define RVTEST_CODE_BEGIN \
        .section .text;   \
        .align 2;         \
        .globl _start;    \
_start:

#define RVTEST_CODE_END

#define RVTEST_PASS \
        li a0, 0;   \
        ecall;

#define RVTEST_FAIL         \
        sll a0, TESTNUM, 1; \
        or  a0, a0, 1;      \
        ecall;

#define RVTEST_DATA_BEGIN .align 4; .global begin_signature; begin_signature:
#define RVTEST_DATA_END   .align 4; .global end_signature;   end_signature:

#endif
