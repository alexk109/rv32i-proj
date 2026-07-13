.section .text
.globl _start
_start:

    li   gp, 1
    li   x1, 5
    li   x2, 7
    sub  x4, x1, x2
    li   x5, -2
    bne  x4, x5, fail

    li   gp, 2
    li   x1, 0xF0F0F0F0
    li   x2, 0x0FF00FF0
    xor  x4, x1, x2
    li   x5, 0xFF00FF00
    bne  x4, x5, fail

    li   gp, 3
    or   x4, x1, x2
    li   x5, 0xFFF0FFF0
    bne  x4, x5, fail

    li   gp, 4
    and  x4, x1, x2
    li   x5, 0x00F000F0
    bne  x4, x5, fail

    li   gp, 5
    li   x1, 0x7FFFFFFF
    li   x2, 1
    add  x4, x1, x2
    li   x5, 0x80000000
    bne  x4, x5, fail

    li   gp, 6
    li   x1, 1
    li   x2, 31
    sll  x4, x1, x2
    li   x5, 0x80000000
    bne  x4, x5, fail

    li   gp, 7
    li   x1, 1
    li   x2, 32
    sll  x4, x1, x2
    li   x5, 1
    bne  x4, x5, fail

    li   gp, 8
    li   x1, 0x80000000
    srli x4, x1, 4
    li   x5, 0x08000000
    bne  x4, x5, fail

    li   gp, 9
    li   x1, 0x80000000
    srai x4, x1, 4
    li   x5, 0xF8000000
    bne  x4, x5, fail

    li   gp, 10
    li   x1, 0x80000000
    srai x4, x1, 31
    li   x5, -1
    bne  x4, x5, fail

    li   gp, 11
    li   x1, 0x80000000
    srai x4, x1, 0
    bne  x4, x1, fail

    li   gp, 12
    li   x1, -1
    li   x2, 1
    slt  x4, x1, x2
    li   x5, 1
    bne  x4, x5, fail

    li   gp, 13
    sltu x4, x1, x2
    bne  x4, x0, fail

    li   gp, 14
    slt  x4, x1, x1
    bne  x4, x0, fail

    li   gp, 15
    li   x1, -1
    slti x4, x1, 0
    li   x5, 1
    bne  x4, x5, fail

    li   gp, 16
    sltiu x4, x0, -1
    li   x5, 1
    bne  x4, x5, fail

    li   gp, 17
    li   x1, 0x80000000
    srai x4, x1, 4
    srli x5, x1, 4
    beq  x4, x5, fail

    li   gp, 18
    li   x1, 0x80000000
    li   x2, 4
    sra  x4, x1, x2
    li   x5, 0xF8000000
    bne  x4, x5, fail

    li   gp, 19
    srl  x4, x1, x2
    li   x5, 0x08000000
    bne  x4, x5, fail

    li   a0, 0
    ecall

fail:
    sll  a0, gp, 1
    or   a0, a0, 1
    ecall
