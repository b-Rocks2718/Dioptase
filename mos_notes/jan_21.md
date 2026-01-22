# MOS Notes 1/21

## Compilation Process

Start with x.c
- Preprocessor: x.c -> x.c (expand #directives)
- Compiler: x.c -> x.s (compile to assembly)
  - templates
  - inline
  - constant folding
- Assembler: x.s -> x.o (assemble to object file)
- Linker: x.o -> x (link.o files to produce executable)

C extension to specify the section of code/data: `__attribute__((section("name")))`

Kernel code can tell the bootloader what sections to load things in

.init_array section has pointers to global constructor functions
