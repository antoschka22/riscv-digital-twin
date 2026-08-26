/* linker.ld */
OUTPUT_ARCH( "riscv" )
ENTRY( _start ) /* The entry point of our program */

MEMORY
{
  /* We allocated 1MB in memory.cpp, starting at 0x00000000 */
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 1M
}

SECTIONS
{
  /* The code section */
  .text : {
    *(.text.init) /* Force our startup assembly to be at the very beginning! */
    *(.text*)
  } > RAM

  /* Read-only data (like our "Hello World" string) */
  .rodata : {
    *(.rodata*)
  } > RAM

  /* Initialized variables */
  .data : {
    *(.data*)
  } > RAM

  /* Uninitialized variables */
  /* Uninitialized variables */
  .bss : {
    . = ALIGN(4);
    __bss_start = .;
    *(.bss*)
    *(.sbss*)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM

  /* Define a symbol for the top of the stack (End of 1MB RAM) */
  __stack_top = ORIGIN(RAM) + LENGTH(RAM); 
}