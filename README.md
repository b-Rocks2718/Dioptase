# Dioptase

Top level repo for the Dioptase project.  
32-bit evolution of the [JPEB project](https://github.com/PaulBailey-1/JPEB)

The goal is to build an FPGA computer from scratch - creating an ISA, verilog processor, assembler, compiler, and OS.

[ISA](https://github.com/b-Rocks2718/Dioptase/blob/main/docs/ISA.md)  
[Memory Map](https://github.com/b-Rocks2718/Dioptase/blob/main/docs/mem_map.md)

I/O devices:
 - PS/2 Keyboard
 - VGA Monitor
 - SD card storage
 - UART
 - PIT (Programmable Interrupt Timer)

Clone the repo with `git clone --recurse-submodules`  
Pull the updates with `git pull --recurse-submodules`

`make all` will build everything in all the subrepos

`make test` will test all the subrepos


## Progress

- [Assembler](https://github.com/b-Rocks2718/Dioptase-Assembler) (Done)
- Emulators:
  - [User ISA Emulator](https://github.com/b-Rocks2718/Dioptase-Emulator-Simple) (Done)
  - [Full ISA Emulator](https://github.com/b-Rocks2718/Dioptase-Emulator-Full) (In Progress)
- Processors:
  - [User ISA Pipeline](https://github.com/b-Rocks2718/Dioptase-Pipe-Simple) (Done)
  - Full ISA Pipeline (Not yet started)
- Languages:
  - [C Compiler](https://github.com/b-Rocks2718/Dioptase-C-Compiler) (In progress)
  - Lox Interpreter (Not yet started)
- OS (Not yet started)