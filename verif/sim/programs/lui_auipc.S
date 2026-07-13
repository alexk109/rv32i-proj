.section .text
.globl _start
_start:

    li   gp, 1
    lui  x1, 0x12345
    li   x4, 0x123
    slli x4, x4, 8
    addi x4, x4, 0x45
    slli x4, x4, 12
    bne  x1, x4, fail

    li   gp, 2
    lui  x1, 0xFFFFF
    li   x4, 0xFFFFF000
    bne  x1, x4, fail

    li   gp, 3
    lui  x1, 0
    bne  x1, x0, fail

    li   gp, 4
    lui  x1, 0x80000
    li   x4, 0x80000000
    bne  x1, x4, fail

    li   gp, 5
    auipc x1, 0
    auipc x2, 0
    sub  x4, x2, x1
    li   x5, 4
    bne  x4, x5, fail

    li   gp, 6
    auipc x1, 0
    auipc x2, 1
    sub  x4, x2, x1
    li   x5, 0x1004
    bne  x4, x5, fail

    li   gp, 7
    auipc x1, 0
    nop
    nop
    auipc x2, 0
    sub  x4, x2, x1
    li   x5, 12
    bne  x4, x5, fail

    li   a0, 0
    ecall

fail:
    sll  a0, gp, 1
    or   a0, a0, 1
    ecall
