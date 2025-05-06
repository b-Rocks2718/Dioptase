# ISA:

32 bit registers, 32 bit instructions, 32 registers (r0 - r31)

Reads from `r0` always return 0, writes to `r0` are ignored. `r1` will be preferred stack pointer, `r2` preferred base pointer. Return addresses will prefer to be placed in `r31`

5 bit opcodes, 4 flags (Zero, Sign, Carry, Overflow)

2 modes: user mode and kernel mode

Kernel mode will allow privileged instructions, user mode will raise an exception on privileged instructions. 

Memory is byte addressable, misaligned pc will raise an exception, I think misaligned loads/stores should be allowed

### Control Registers:   
`cr0` = PSR (processor status register, shift register holding kmode history of the processor)  
`cr1` = PID (holds PID of currently executing process)  
`cr2` = ISR (interrupt status register, holds which interrupts are active)  
`cr3` = IMR (interrupt mask register, enables various interrupts. Top bit enables/disables all interrupts)   
`cr4` = EPC (exceptional PC, pc is placed here after interrupt, syscall, or exception)  
`cr5` = EFG (exceptional flags, flags are placed here after interrupt, syscall, or exception)  
`cr6` = CDV (clock divider register, sets clock rate)

On interrupt/exception/syscall, top bit of IMR is set to disable further interrupts. The kernel must clear it after saving pc and flags to enable nested interrupts

OS page size: 4KB  
When in user mode, all addresses are mapped by the TLB.
When in kernel mode, the bottom 64K of address space does not go through the tlb

## User Instructions:

### 3 Register ALU Instructions

rA is destination, rB and rC are sources

Opcode is 00000

(x -> unused bits)

Bitwise logic:  
00000aaaaabbbbbxxxxxxx00000ccccc - and   rA, rB, rC  
00000aaaaabbbbbxxxxxxx00001ccccc - nand rA, rB, rC    
00000aaaaabbbbbxxxxxxx00010ccccc - or      rA, rB, rC  
00000aaaaabbbbbxxxxxxx00011ccccc - nor    rA, rB, rC  
00000aaaaabbbbbxxxxxxx00100ccccc - xor    rA, rB, rC  
00000aaaaabbbbbxxxxxxx00101ccccc - xnor  rA, rB, rC  
00000aaaaaxxxxxxxxxxxx00110ccccc -  not    rA, rC  

shifts:  
00000aaaaabbbbbxxxxxxx00111ccccc - lsl      rA, rB, rC (logical shift left)  
00000aaaaabbbbbxxxxxxx01000ccccc - lsr     rA, rB, rC (logical shift right)  
00000aaaaabbbbbxxxxxxx01001ccccc - asr    rA, rB, rC (arithmetic shift right)  
00000aaaaabbbbbxxxxxxx01010ccccc - rotl    rA, rB, rC (rotate left)  
00000aaaaabbbbbxxxxxxx01011ccccc - rotr    rA, rB, rC (rotate right)  
00000aaaaabbbbbxxxxxxx01100ccccc - shlc   rA, rB, rC (shift left through carry)  
00000aaaaabbbbbxxxxxxx01101ccccc - shrc   rA, rB, rC (shift right through carry)  

arithmetic:  
00000aaaaabbbbbxxxxxxx01110ccccc - add   rA, rB, rC  
00000aaaaabbbbbxxxxxxx01111ccccc - addc  rA, rB, rC (add with carry)  
00000aaaaabbbbbxxxxxxx10000ccccc - sub   rA, rB, rC  
00000aaaaabbbbbxxxxxxx10001ccccc - subb  rA, rB, rC (subtract with borrow)  
00000aaaaabbbbbxxxxxxx10010ccccc - mul   rA, rB, rC

Plenty of instruction space to expand this over time

### ALU immediate instructions

rA is destination, rB is source, i is immediate

Opcode is 00001

(x -> unused bits)

Bitwise logic:   
yy is 2 bit code used to decode immediate  
i is 8 bit immediate

i is decoded as (i << (8 * y))

So i = 0x0F and y = 0 decodes as  0x0000000F  
But i = 0x0F and y = 2 decodes as 0x000F0000

00001aaaaabbbbb00000yyxxiiiiiiii - and  rA, rB, i   
00001aaaaabbbbb00001yyxxiiiiiiii - nand rA, rB, i   
00001aaaaabbbbb00010yyxxiiiiiiii - or      rA, rB, i   
00001aaaaabbbbb00011yyxxiiiiiiii - nor    rA, rB, i   
00001aaaaabbbbb00100yyxxiiiiiiii - xor    rA, rB, i  
00001aaaaabbbbb00101yyxxiiiiiiii - xnor  rA, rB, i  
00001aaaaaxxxxx00110yyxxiiiiiiii -  not    rA, i  

Shifts:  
i is 5 bit immediate

00001aaaaabbbbb00111xxxxxxxiiiii - lsl      rA, rB, i  
00001aaaaabbbbb01000xxxxxxxiiiii - lsr     rA, rB, i  
00001aaaaabbbbb01001xxxxxxxiiiii - asr    rA, rB, i  
00001aaaaabbbbb01010xxxxxxxiiiii - rotl    rA, rB, i  
00001aaaaabbbbb01011xxxxxxxiiiii - rotr    rA, rB, i  
00001aaaaabbbbb01100xxxxxxxiiiii - shlc   rA, rB, i  
00001aaaaabbbbb01101xxxxxxxiiiii - shrc   rA, rB, i  

Arithmetic:  
i is 12 bit immediate, sign extended to 32 bits
00001aaaaabbbbb01110iiiiiiiiiiii  - add    rA, rB, i  
00001aaaaabbbbb01111iiiiiiiiiiii -  addc  rA, rB, i  
00001aaaaabbbbb10000iiiiiiiiiiii - sub    rA, rB, i // not really necessary  
00001aaaaabbbbb10001iiiiiiiiiiii - subb  rA, rB, i   
00001aaaaabbbbb10010iiiiiiiiiiii - mul    rA, rB, i  

some instruction space to expand this over time

### lui (Load Upper Immediate)

Opcode is 00010

i is 22 bit immediate, shifted left by 10 to make a 32 bit value

rA is target

Use with addi to move any 32 bit value into a register

00010aaaaaiiiiiiiiiiiiiiiiiiiiii - lui rA, i

### Memory 

Opcode is 00011

rA is data, rB is base, y is offset type, z is shift amount (0 to 3), i is 12 bit immediate, sign extended to 32 bits

y = 0 - signed offset  
y = 1 - preincrement  
y = 2 - postincrement

00011aaaaabbbbbyyzz0iiiiiiiiiiii sw rA, rB, i  
00011aaaaabbbbbyyzz1iiiiiiiiiiii lw  rA, rB, i 

suggestions for syntax to denote offset type and shift? Steal arm’s?

### Immediate Branches

Opcode is 00100

5 bit branch code determines which condition to use. i is 22 bit immediate, sign extended to 32 bit    
If condition is met, branches to pc + 1 + i

0010000000iiiiiiiiiiiiiiiiiiiiii - br i      (unconditional branch)  
0010000001iiiiiiiiiiiiiiiiiiiiii - bz i     (branch if zero)  
0010000010iiiiiiiiiiiiiiiiiiiiii - bnz i   (branch if nonzer)  
0010000011iiiiiiiiiiiiiiiiiiiiii - bs i     (branch if sign [negative])  
0010000100iiiiiiiiiiiiiiiiiiiiii - bns i   (branch not sign [not negative])  
0010000101iiiiiiiiiiiiiiiiiiiiii - bc i     (branch if carry)  
0010000110iiiiiiiiiiiiiiiiiiiiii - bnc i   (branch if not carry)  
0010000111iiiiiiiiiiiiiiiiiiiiii - bo i     (branch if overflow)  
0010001000iiiiiiiiiiiiiiiiiiiiii - bno i  (branch if not overflow)  
0010001001iiiiiiiiiiiiiiiiiiiiii - bp i    (branch if positive)  
0010001010iiiiiiiiiiiiiiiiiiiiii - bnp i  (branch if not positive)  
0010001011iiiiiiiiiiiiiiiiiiiiii - bg i    (branch if greater [signed])  
0010001100iiiiiiiiiiiiiiiiiiiiii - bge i  (branch if greater or equal [signed])  
0010001101iiiiiiiiiiiiiiiiiiiiii - bl i     (branch if less [signed])  
0010001110iiiiiiiiiiiiiiiiiiiiii - ble i   (branch if less or equal [signed])  
0010001111iiiiiiiiiiiiiiiiiiiiii - ba i    (branch if above [unsigned])  
0010010000iiiiiiiiiiiiiiiiiiiiii - bae i (branch if above or equal [unsigned])  
0010010001iiiiiiiiiiiiiiiiiiiiii - bb i    (branch if below [unsigned])  
0010010010iiiiiiiiiiiiiiiiiiiiii - bbe i (branch if below or equal [unsigned])  

Leaves room if more branch conditions are ever needed

### Register Branches

Opcode is 00101

Branch and link register

5 bit branch code determines which condition to use.
If condition is met, branches to rB and stores pc + 1 in rA (set rA as r0 if you don’t want to save it)

0010100000xxxxxxxxxxxxaaaaabbbbb - brl rA, rB     (unconditional branch)  
0010100001xxxxxxxxxxxxaaaaabbbbb - bzl rA, rB     (branch if zero)  
0010100010xxxxxxxxxxxxaaaaabbbbb - bnzl rA, rB   (branch if nonzer)  
0010100011xxxxxxxxxxxxaaaaabbbbb - bsl rA, rB     (branch if sign [negative])  
0010100100xxxxxxxxxxxxaaaaabbbbb - bnsl rA, rB   (branch not sign [not negative])  
0010100101xxxxxxxxxxxxaaaaabbbbb - bcl rA, rB     (branch if carry)  
0010100110xxxxxxxxxxxxaaaaabbbbb - bncl rA, rB   (branch if not carry)  
0010100111xxxxxxxxxxxxaaaaabbbbb - bol rA, rB     (branch if overflow)  
0010101000xxxxxxxxxxxxaaaaabbbbb - bnol rA, rB  (branch if not overflow)  
0010101001xxxxxxxxxxxxaaaaabbbbb - bpl rA, rB    (branch if positive)  
0010101010xxxxxxxxxxxxaaaaabbbbb - bnpl rA, rB  (branch if not positive)  
0010101011xxxxxxxxxxxxaaaaabbbbb - bgl rA, rB    (branch if greater [signed])  
0010101100xxxxxxxxxxxxaaaaabbbbb - bgel rA, rB  (branch if greater or equal [signed])  
0010101101xxxxxxxxxxxxaaaaabbbbb - bll rA, rB     (branch if less [signed])  
0010101110xxxxxxxxxxxxaaaaabbbbb - blel rA, rB   (branch if less or equal [signed])  
0010101111xxxxxxxxxxxxaaaaabbbbb - bal rA, rB    (branch if above [unsigned])  
0010110000xxxxxxxxxxxxaaaaabbbbb - bael rA, rB  (branch if above or equal [unsigned])
0010110001xxxxxxxxxxxxaaaaabbbbb - bbl rA, rB    (branch if below [unsigned])  
0010110010xxxxxxxxxxxxaaaaabbbbb - bbel rA, rB  (branch if below or equal [unsigned])  

Leaves room if more branch conditions are ever needed

### Syscalls

Opcode is 00111

List will expand as we go

i is 7 bit immediate specifying which exception to raise

00111xxxxxxxxxxxxxxxxxxxxiiiiiii

For now, we’ll start with supporting

00111xxxxxxxxxxxxxxxxxxxx0000000 - sys EXIT, returning control from the user code to the OS


## Privileged Instructions:

Opcode - 11111
All share opcode, distinguished by 5 bit id following rB

### Tlb reads/writes/clear   
id - 00000

11111aaaaabbbbb0000000xxxxxxxxxx - tlbr rA, rB - if rB exists in tlb, put its map in rA, otherwise put 0 in rA (tlb shouldn’t ever map stuff to the very bottom of the address space)

11111aaaaabbbbb0000001xxxxxxxxxx - tlbw rA, rB - write a new tlb entry mapping rB to rA

11111xxxxxxxxxx000001xxxxxxxxxxx - tlbc - clear tlb

### Mov to/from control regs
id - 00001

11111aaaaabbbbb000010xxxxxxxxxxx - tocr crA, rB - move rB into control register crA
11111aaaaabbbbb000011xxxxxxxxxxx - fmcr rA, crB - move control register crB into rA

### Set mode - run, sleep, halt
id - 00010

11111xxxxxxxxxx0001000xxxxxxxxxx - mode run  
11111xxxxxxxxxx0001001xxxxxxxxxx - mode sleep (awakened by interrupt)  
11111xxxxxxxxxx0001010xxxxxxxxxx - mode halt

### Return from interrupt/return from exception
id - 00011

11111aaaaaxxxxx000110xxxxxxxxxxx   rfe rA - (return from exception) update kmode and jump to rA + 1

11111aaaaaxxxxx000111xxxxxxxxxxx   rfi rA - (return from interrupt) update kmode and jump to rA


Leaves lots of unused opcodes, so the ISA can be expanded over time

## Exceptions:

All exceptions, interrupts, and syscalls cause the processor to enter kernel mode and jump to the address specified in the interrupt vector table (IVT).

### Exception types:

Invalid instruction exception  
Privileges exception  
Tlb umiss exception  
Tlb kmiss exception  
Misaligned pc exception


