.section .text
.globl _start
_start:

    li   gp, 1
    li   x1, 5
    li   x2, 5
    li   x4, 0
    beq  x1, x2, 1f
    li   x4, 99
1:  bne  x4, x0, fail

    li   gp, 2
    li   x1, 5
    li   x2, 6
    li   x4, 0
    beq  x1, x2, 1f
    li   x4, 99
1:  li   x5, 99
    bne  x4, x5, fail

    li   gp, 3
    li   x1, 5
    li   x2, 6
    li   x4, 0
    bne  x1, x2, 1f
    li   x4, 99
1:  bne  x4, x0, fail

    li   gp, 4
    li   x2, 5
    li   x4, 0
    bne  x1, x2, 1f
    li   x4, 99
1:  li   x5, 99
    bne  x4, x5, fail

    li   gp, 5
    li   x1, -1
    li   x2, 1
    li   x4, 0
    blt  x1, x2, 1f
    li   x4, 99
1:  bne  x4, x0, fail

    li   gp, 6
    li   x4, 0
    blt  x2, x1, 1f
    li   x4, 99
1:  li   x5, 99
    bne  x4, x5, fail

    li   gp, 7
    li   x4, 0
    bge  x2, x1, 1f
    li   x4, 99
1:  bne  x4, x0, fail

    li   gp, 8
    li   x4, 0
    bge  x1, x2, 1f
    li   x4, 99
1:  li   x5, 99
    bne  x4, x5, fail

    li   gp, 9
    li   x4, 0
    bltu x1, x2, 1f
    li   x4, 99
1:  li   x5, 99
    bne  x4, x5, fail

    li   gp, 10
    li   x4, 0
    bltu x2, x1, 1f
    li   x4, 99
1:  bne  x4, x0, fail

    li   gp, 11
    li   x4, 0
    bgeu x1, x2, 1f
    li   x4, 99
1:  bne  x4, x0, fail

    li   gp, 12
    li   x4, 0
    bgeu x2, x1, 1f
    li   x4, 99
1:  li   x5, 99
    bne  x4, x5, fail

    li   gp, 13
    li   x1, -1
    li   x2, 1
    li   x4, 0
    blt  x1, x2, 1f
    li   x4, 99
1:  bne  x4, x0, fail
    li   x4, 0
    bltu x1, x2, 2f
    li   x4, 99
2:  li   x5, 99
    bne  x4, x5, fail

    li   gp, 14
    li   x6, 0
    li   x7, 3
1:  addi x6, x6, 1
    blt  x6, x7, 1b
    bne  x6, x7, fail

    li   gp, 15
    li   x1, -1
    li   x4, 0
    beq  x0, x1, 1f
    addi x4, x4, 7
1:  li   x5, 7
    bne  x4, x5, fail

    li   gp, 16
    li   x1, 0
    li   x2, 0
    li   x4, 0
    bge  x1, x2, 1f
    li   x4, 99
1:  bne  x4, x0, fail

    li   gp, 17
    li   x4, 0
    bgeu x1, x2, 1f
    li   x4, 99
1:  bne  x4, x0, fail

    li   a0, 0
    ecall

fail:
    sll  a0, gp, 1
    or   a0, a0, 1
    ecall
