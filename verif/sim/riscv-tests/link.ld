OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0x0;
  .text : { *(.text.init) *(.text) }
  . = ALIGN(16);
  .data : { *(.data) *(.rodata*) *(.sdata*) *(.srodata*) }
  .bss  : { *(.bss) *(.sbss*) }
  _end = .;
}
