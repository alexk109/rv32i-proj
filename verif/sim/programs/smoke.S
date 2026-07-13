# Level 1 smoke test — proves the datapath is wired, nothing more.
#
# gp holds the subtest number while running; 0 on exit means everything passed.

.section .text
.globl _start
_start:

    li   gp, 1
    addi x1, x0, 5
    addi x2, x0, 7
    add  x4, x1, x2
    li   x5, 12
    bne  x4, x5, fail

    li   gp, 2
    li   x6, 0x40
    sw   x4, 0(x6)
    lw   x7, 0(x6)
    bne  x7, x4, fail

    li   gp, 3
    li   x8, 0
    beq  x4, x7, taken
    li   x8, 99
taken:
    bne  x8, x0, fail

    li   a0, 0
    ecall

fail:
    sll  a0, gp, 1
    or   a0, a0, 1
    ecall
