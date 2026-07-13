.section .text
.globl _start
_start:

    li   gp, 1
    li   x4, 0
    jal  x1, 1f
    li   x4, 99
1:  bne  x4, x0, fail

    li   gp, 2
    jal  x5, 2f
2:  auipc x6, 0
    bne  x5, x6, fail

    li   gp, 3
    li   x6, 0
    jal  x0, 4f
3:  addi x6, x6, 1
    jal  x0, 5f
4:  jal  x0, 3b
5:  li   x5, 1
    bne  x6, x5, fail

    li   gp, 4
    la   x7, 6f
    li   x4, 0
    jalr x1, x7, 0
    li   x4, 99
6:  bne  x4, x0, fail

    li   gp, 5
    la   x7, 7f
    addi x7, x7, -8
    li   x4, 0
    jalr x1, x7, 8
    li   x4, 99
7:  bne  x4, x0, fail

    li   gp, 6
    la   x7, 8f
    jalr x1, x7, 1
8:  auipc x8, 0
    bne  x8, x7, fail

    li   gp, 7
    la   x7, 9f
    li   x4, 0
    jalr x0, x7, 0
    li   x4, 99
9:  bne  x4, x0, fail
    bne  x0, x0, fail

    li   gp, 8
    li   x4, 0
    jal  x1, subr
    li   x5, 42
    bne  x4, x5, fail

    li   gp, 9
    la   x7, 10f
    jalr x11, x7, 0
10: auipc x12, 0
    bne  x11, x12, fail

    li   gp, 0
    ecall

subr:
    li   x4, 42
    jalr x0, x1, 0

fail:
    ecall
