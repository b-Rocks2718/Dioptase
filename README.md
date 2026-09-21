# Dioptase

[![Software CI](https://github.com/b-Rocks2718/Dioptase/actions/workflows/software-ci.yml/badge.svg?branch=main)](https://github.com/b-Rocks2718/Dioptase/actions/workflows/software-ci.yml)

Top level repo for the Dioptase project.  
32-bit evolution of the [JPEB project](https://github.com/PaulBailey-1/JPEB)

The goal is to build an FPGA computer from scratch - creating an ISA, verilog processor, assembler, compiler, and OS.

[ISA](https://github.com/b-Rocks2718/Dioptase/blob/main/docs/ISA.md)  
[ABI](https://github.com/b-Rocks2718/Dioptase/blob/main/docs/abi.md)  
[Memory Map](https://github.com/b-Rocks2718/Dioptase/blob/main/docs/mem_map.md)  

I/O devices:
 - PS/2 Keyboard
 - PS/2 Mouse
 - VGA Monitor
 - PWM Audio
 - SD card storage (will have two of these)
 - UART
 - PIT (Programmable Interrupt Timer)

Clone the repo with `git clone --recurse-submodules`  
Pull the updates with `git pull --recurse-submodules`

`make all` will build everything in all the subrepos

`make test` will test all the subrepos

`make analysis` runs Clang Static Analyzer, Rust Clippy, and Verilator lint.
See [static analysis setup and reports](docs/static-analysis.md) for dependencies,
component-specific commands, and limitations.
Each software submodule's CI script runs its corresponding C or Rust analysis;
Verilog lint remains a local, optional check.

`make valgrind` runs Valgrind Memcheck over the native assembler and compiler
debug suites. These checks also run automatically in both tools' CI jobs. See
[dynamic memory analysis](docs/dynamic-analysis.md) for scope, dependencies,
and component-specific commands.

See [CI dependency model](docs/ci.md) for how hosted subrepo and root workflows
select compatible versions of sibling repositories.

`source env.sh` to add `basm`, `bemu`, and `bcc` to `PATH`  
`env.sh` also exports `DIOPTASE_ROOT` for portable tool lookup
- Assembler CRT lookup: `DIOPTASE_CRT_DIR` (preferred) or `DIOPTASE_ROOT` + `Dioptase-OS/root/crt`
- Compiler assembler lookup: `DIOPTASE_ASSEMBLER` (preferred) or `DIOPTASE_ROOT` + `Dioptase-Assembler/build/*/basm`

## Progress

- [Assembler](https://github.com/b-Rocks2718/Dioptase-Assembler) (Done)
- Emulators:
  - [User ISA Emulator](https://github.com/b-Rocks2718/Dioptase-Emulator-Simple) (Done)
  - [Full ISA Emulator](https://github.com/b-Rocks2718/Dioptase-Emulator-Full) (Done except for mouse and sound)
- Processors:
  - [User ISA Pipeline](https://github.com/b-Rocks2718/Dioptase-Pipe-Simple) (Done)
  - [Full ISA Pipeline](https://github.com/b-Rocks2718/Dioptase-Pipe-Full) (In progress)
- Languages:
  - [C Compiler](https://github.com/b-Rocks2718/Dioptase-C-Compiler) (Good enough for now)
- [OS](https://github.com/b-Rocks2718/Dioptase-OS) (In progress)
