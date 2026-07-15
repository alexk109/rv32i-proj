# Startup code for C programs.
#
# -nostdlib means there is no C runtime, so this is it. C needs three things
# before main() can run: a stack pointer, a zeroed .bss, and somewhere to return
# to. This provides all three.

.section .text.init
.globl _start
_start:

    # The stack lives at the top of data_mem (1024 words = 4 KiB) and grows down.
    # sp points one past the end; the first push lands at 0xFFC.
    li   sp, 0x1000

    # Zero .bss. objcopy -O binary emits no bytes for .bss, so whatever those
    # words hold at reset is undefined -- and with --x-initial unique, actively
    # random. Uninitialised globals must be zeroed here or they are garbage.
    la   t0, __bss_start
    la   t1, __bss_end
1:  bge  t0, t1, 2f
    sw   x0, 0(t0)
    addi t0, t0, 4
    j    1b
2:

    call main

    # main() returned. Its value is already in a0, which is exactly the pass/fail
    # register the testbench reads: 0 means pass.
    ecall
