# Pipeline hazard corners — forwarding, load-use, and control paths that a
# single-cycle core can't have. Each subtest is self-checking (gp = subtest, a0=0
# on exit) AND is diffed against the single-cycle golden model, so both the
# expected value and the retirement stream are verified.

.section .text
.globl _start
_start:

    # base address for loads/stores
    li   x9, 0x40

    # 1: EX/MEM forward to rs1 (distance 1)
    li   gp, 1
    addi x1, x0, 5
    add  x2, x1, x0
    li   x5, 5
    bne  x2, x5, fail

    # 2: EX/MEM forward to rs2 (distance 1)
    li   gp, 2
    addi x1, x0, 7
    add  x2, x0, x1
    li   x5, 7
    bne  x2, x5, fail

    # 3: MEM/WB forward (distance 2, one filler between)
    li   gp, 3
    addi x1, x0, 9
    addi x6, x0, 123
    add  x2, x1, x0
    li   x5, 9
    bne  x2, x5, fail

    # 4: newer-producer-wins (two writes to x1 back-to-back)
    li   gp, 4
    addi x1, x0, 1
    addi x1, x1, 1
    add  x2, x1, x0
    li   x5, 2
    bne  x2, x5, fail

    # 5: x0 is never forwarded
    li   gp, 5
    addi x0, x1, 99
    add  x2, x0, x0
    bne  x2, x0, fail

    # 6: JAL link forwarded at distance 1 (the bug BTFN exposed)
    li   gp, 6
    jal  x1, 1f
1:  add  x2, x1, x0
    bne  x2, x1, fail

    # 7: forward into store DATA (rs2 of a store)
    li   gp, 7
    addi x1, x0, 0x55
    sw   x1, 0(x9)
    lw   x2, 0(x9)
    li   x5, 0x55
    bne  x2, x5, fail

    # 8: forward into store ADDRESS (rs1 of a store)
    li   gp, 8
    addi x1, x9, 4
    sw   x6, 0(x1)
    lw   x2, 4(x9)
    li   x5, 123
    bne  x2, x5, fail

    # 9: forward into branch operand (branch resolves in EX)
    li   gp, 9
    addi x1, x0, 42
    addi x2, x0, 42
    bne  x1, x2, fail

    # 10: load-use hazard (must stall one cycle)
    li   gp, 10
    addi x1, x0, 0x77
    sw   x1, 8(x9)
    lw   x3, 8(x9)
    add  x4, x3, x0
    li   x5, 0x77
    bne  x4, x5, fail

    # 11: load feeding a branch (load-use into branch)
    li   gp, 11
    lw   x3, 8(x9)
    li   x5, 0x77
    bne  x3, x5, fail

    # 12: load then use two later (forward from WB, no stall needed)
    li   gp, 12
    lw   x3, 8(x9)
    addi x7, x0, 1
    add  x4, x3, x0
    li   x5, 0x77
    bne  x4, x5, fail

    # 13: JALR base forwarded at distance 1 (jump skips the x4=99 instruction)
    li   gp, 13
    addi  x4, x0, 0
    auipc x1, 0
    jalr  x0, x1, 12
    addi  x4, x0, 99
    bne   x4, x0, fail

    li   a0, 0
    ecall

fail:
    sll  a0, gp, 1
    or   a0, a0, 1
    ecall
