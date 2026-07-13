.section .text
.globl _start
_start:

    li   x5, 0

    li   gp, 1
    addi x0, x0, 5
    bne  x0, x5, fail

    li   gp, 2
    li   x9, 0x40
    li   x1, 0xDEADBEEF
    sw   x1, 0(x9)
    lw   x0, 0(x9)
    bne  x0, x5, fail

    li   gp, 3
    add  x1, x0, x0
    bne  x1, x5, fail

    li   gp, 4
    li   x4, 0
    jal  x0, 1f
    li   x4, 99
1:  bne  x0, x5, fail
    bne  x4, x0, fail

    li   gp, 5
    li   x1, 5
    add  x4, x1, x0
    bne  x4, x1, fail

    li   gp, 6
    lui  x0, 0x12345
    bne  x0, x5, fail

    li   gp, 7
    li   x1, -1
    sub  x0, x0, x1
    bne  x0, x5, fail

    li   a0, 0
    ecall

fail:
    sll  a0, gp, 1
    or   a0, a0, 1
    ecall
