.section .text
.globl _start
_start:

    li   x9, 0x40

    li   gp, 1
    li   x1, 0xDEADBEEF
    sw   x1, 0(x9)
    lw   x2, 0(x9)
    bne  x2, x1, fail

    li   gp, 2
    li   x1, 0x11111111
    li   x2, 0x22222222
    sw   x1, 0(x9)
    sw   x2, 4(x9)
    lw   x4, 0(x9)
    bne  x4, x1, fail
    lw   x5, 4(x9)
    bne  x5, x2, fail

    li   gp, 3
    sw   x0, 0(x9)
    li   x1, 0xAA
    sb   x1, 0(x9)
    lw   x4, 0(x9)
    li   x5, 0x000000AA
    bne  x4, x5, fail

    li   gp, 4
    sw   x0, 0(x9)
    sb   x1, 1(x9)
    lw   x4, 0(x9)
    li   x5, 0x0000AA00
    bne  x4, x5, fail

    li   gp, 5
    sw   x0, 0(x9)
    sb   x1, 2(x9)
    lw   x4, 0(x9)
    li   x5, 0x00AA0000
    bne  x4, x5, fail

    li   gp, 6
    sw   x0, 0(x9)
    sb   x1, 3(x9)
    lw   x4, 0(x9)
    li   x5, 0xAA000000
    bne  x4, x5, fail

    li   gp, 7
    li   x1, -1
    sw   x1, 0(x9)
    sb   x0, 2(x9)
    lw   x4, 0(x9)
    li   x5, 0xFF00FFFF
    bne  x4, x5, fail

    li   gp, 8
    sw   x0, 0(x9)
    li   x1, 0xFF
    sb   x1, 0(x9)
    lb   x4, 0(x9)
    li   x5, -1
    bne  x4, x5, fail

    li   gp, 9
    lbu  x4, 0(x9)
    li   x5, 0xFF
    bne  x4, x5, fail

    li   gp, 10
    li   x1, 0x7F
    sb   x1, 0(x9)
    lb   x4, 0(x9)
    li   x5, 0x7F
    bne  x4, x5, fail

    li   gp, 11
    li   x1, 0x04030201
    sw   x1, 0(x9)
    lb   x4, 0(x9)
    li   x5, 1
    bne  x4, x5, fail
    lb   x4, 1(x9)
    li   x5, 2
    bne  x4, x5, fail
    lb   x4, 2(x9)
    li   x5, 3
    bne  x4, x5, fail
    lb   x4, 3(x9)
    li   x5, 4
    bne  x4, x5, fail

    li   gp, 12
    sw   x0, 0(x9)
    li   x1, 0xBBBB
    sh   x1, 0(x9)
    lw   x4, 0(x9)
    li   x5, 0x0000BBBB
    bne  x4, x5, fail

    li   gp, 13
    sw   x0, 0(x9)
    sh   x1, 2(x9)
    lw   x4, 0(x9)
    li   x5, 0xBBBB0000
    bne  x4, x5, fail

    li   gp, 14
    li   x1, -1
    sw   x1, 0(x9)
    sh   x0, 0(x9)
    lw   x4, 0(x9)
    li   x5, 0xFFFF0000
    bne  x4, x5, fail

    li   gp, 15
    sw   x0, 0(x9)
    li   x1, 0xFFFF
    sh   x1, 0(x9)
    lh   x4, 0(x9)
    li   x5, -1
    bne  x4, x5, fail

    li   gp, 16
    lhu  x4, 0(x9)
    li   x5, 0xFFFF
    bne  x4, x5, fail

    li   gp, 17
    li   x1, 0x8000FFFF
    sw   x1, 0(x9)
    lh   x4, 2(x9)
    li   x5, 0xFFFF8000
    bne  x4, x5, fail
    lhu  x4, 2(x9)
    li   x5, 0x8000
    bne  x4, x5, fail

    li   gp, 18
    sw   x0, 0(x9)
    li   x1, 0x11
    sb   x1, 0(x9)
    li   x1, 0x22
    sb   x1, 1(x9)
    li   x1, 0x33
    sb   x1, 2(x9)
    li   x1, 0x44
    sb   x1, 3(x9)
    lw   x4, 0(x9)
    li   x5, 0x44332211
    bne  x4, x5, fail

    li   gp, 19
    li   x13, 0x100
    li   x1, 0xCAFEBABE
    sw   x1, 0(x13)
    lw   x4, 0(x13)
    bne  x4, x1, fail
    lw   x5, 0(x9)
    li   x6, 0x44332211
    bne  x5, x6, fail

    li   a0, 0
    ecall

fail:
    sll  a0, gp, 1
    or   a0, a0, 1
    ecall
