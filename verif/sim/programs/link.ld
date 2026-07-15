/* Link script for C programs on the single-cycle core.
 *
 * The default linker page-aligns .data, which would push it past the end of both
 * memories. This packs everything tightly from address 0, and exports the .bss
 * bounds so crt0 can zero it.
 *
 * The same flat image is loaded into instr_mem AND data_mem (Harvard core, two
 * arrays both based at 0), so .rodata and .data are reachable by loads.
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x0;

  .text : {
    *(.text.init)
    *(.text*)
  }

  . = ALIGN(4);
  .rodata : { *(.rodata*) *(.srodata*) }

  . = ALIGN(4);
  .data : { *(.data*) *(.sdata*) }

  . = ALIGN(4);
  __bss_start = .;
  .bss : { *(.bss*) *(.sbss*) *(COMMON) }
  . = ALIGN(4);
  __bss_end = .;

  _end = .;
}
