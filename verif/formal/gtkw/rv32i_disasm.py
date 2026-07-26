#!/usr/bin/env python3
"""GTKWave translate-filter-process: 32-bit word -> RV32I mnemonic.

Attach in GTKWave with:
    right-click a signal -> Data Format -> Translate Filter Process -> Enable
and point it at this file.

A filter *process* is a long-running program: GTKWave writes one value per line
on stdin and expects exactly one translation per line on stdout. It must stay
alive and flush after every line, or GTKWave hangs waiting.

Values arrive rendered in the signal's current data format, so this accepts hex
(with or without a leading 0x), binary, and decimal, and echoes anything it
cannot parse straight back rather than desynchronising the stream.
"""

import sys

REG = [f"x{i}" for i in range(32)]

BRANCH = {0b000: "beq", 0b001: "bne", 0b100: "blt",
          0b101: "bge", 0b110: "bltu", 0b111: "bgeu"}
LOAD = {0b000: "lb", 0b001: "lh", 0b010: "lw", 0b100: "lbu", 0b101: "lhu"}
STORE = {0b000: "sb", 0b001: "sh", 0b010: "sw"}
OPIMM = {0b000: "addi", 0b010: "slti", 0b011: "sltiu", 0b100: "xori",
         0b110: "ori", 0b111: "andi", 0b001: "slli"}
OP = {(0b000, 0): "add", (0b000, 1): "sub", (0b001, 0): "sll",
      (0b010, 0): "slt", (0b011, 0): "sltu", (0b100, 0): "xor",
      (0b101, 0): "srl", (0b101, 1): "sra", (0b110, 0): "or",
      (0b111, 0): "and"}


def sext(val: int, bits: int) -> int:
    return val - (1 << bits) if val & (1 << (bits - 1)) else val


def disasm(w: int) -> str:
    op = w & 0x7F
    rd, rs1, rs2 = (w >> 7) & 0x1F, (w >> 15) & 0x1F, (w >> 20) & 0x1F
    f3, f7 = (w >> 12) & 0x7, (w >> 25) & 0x7F
    bit30 = (w >> 30) & 1

    if op == 0x37:
        return f"lui {REG[rd]}, 0x{(w >> 12) & 0xFFFFF:x}"
    if op == 0x17:
        return f"auipc {REG[rd]}, 0x{(w >> 12) & 0xFFFFF:x}"
    if op == 0x6F:
        imm = sext(((w >> 31) & 1) << 20 | ((w >> 21) & 0x3FF) << 1
                   | ((w >> 20) & 1) << 11 | ((w >> 12) & 0xFF) << 12, 21)
        return f"jal {REG[rd]}, {imm}"
    if op == 0x67:
        return f"jalr {REG[rd]}, {sext(w >> 20, 12)}({REG[rs1]})"
    if op == 0x63:
        imm = sext(((w >> 31) & 1) << 12 | ((w >> 25) & 0x3F) << 5
                   | ((w >> 8) & 0xF) << 1 | ((w >> 7) & 1) << 11, 13)
        return f"{BRANCH.get(f3, '?branch')} {REG[rs1]}, {REG[rs2]}, {imm:+d}"
    if op == 0x03:
        return f"{LOAD.get(f3, '?load')} {REG[rd]}, {sext(w >> 20, 12)}({REG[rs1]})"
    if op == 0x23:
        imm = sext(((w >> 25) & 0x7F) << 5 | ((w >> 7) & 0x1F), 12)
        return f"{STORE.get(f3, '?store')} {REG[rs2]}, {imm}({REG[rs1]})"
    if op == 0x13:
        if f3 == 0b001:
            return f"slli {REG[rd]}, {REG[rs1]}, {rs2}"
        if f3 == 0b101:
            return f"{'srai' if bit30 else 'srli'} {REG[rd]}, {REG[rs1]}, {rs2}"
        return f"{OPIMM.get(f3, '?opimm')} {REG[rd]}, {REG[rs1]}, {sext(w >> 20, 12)}"
    if op == 0x33:
        return f"{OP.get((f3, bit30), '?op')} {REG[rd]}, {REG[rs1]}, {REG[rs2]}"
    if op == 0x0F:
        return "fence"
    if op == 0x73:
        return "ebreak" if (w >> 20) & 1 else "ecall"
    if w == 0:
        return "-"
    return f"?0x{w:08x}"


def parse(tok: str):
    tok = tok.strip()
    if not tok:
        return None
    if any(c in tok for c in "xXzZuU-") and not tok.lower().startswith("0x"):
        # x/z in the value: undefined, nothing to disassemble
        if set(tok.lower()) <= set("xzu-"):
            return None
    try:
        if tok.lower().startswith("0x"):
            return int(tok, 16)
        if set(tok) <= {"0", "1"} and len(tok) > 8:
            return int(tok, 2)
        return int(tok, 16)
    except ValueError:
        return None


def main() -> None:
    for line in sys.stdin:
        word = parse(line)
        out = disasm(word & 0xFFFFFFFF) if word is not None else line.strip()
        sys.stdout.write(out + "\n")
        sys.stdout.flush()   # GTKWave blocks on the reply; never buffer


if __name__ == "__main__":
    main()
