# ISA:

The [RiSC-16](https://user.eng.umd.edu/~blj/risc/) and its extensions were very helpful for creating this ISA  

32 bit registers, 32 bit instructions, 32 registers (r0 - r31)

Reads from `r0` always return 0, writes to `r0` are ignored. When in kernel mode, accesses to `r31`
alias the `ksp` register by default. While servicing an interrupt or a kernel TLB miss, `r31` aliases
`isp` instead. The `crmv` instruction always accesses the architectural `r31` and does not use aliases.

5 bit opcodes, 4 flags (Zero, Sign, Carry, Overflow)

2 modes: user mode and kernel mode

Kernel mode will allow privileged instructions, user mode will raise an exception on privileged instructions. 

Memory is byte addressable, misaligned pc will raise an exception, misaligned loads/stores will have the address
rounded down to make it aligned (might change this later to have it raise an exception) 

### Control Registers:   
`cr0` = PSR (processor status register, counter holding kmode history of the processor)  
`cr1` = PID (holds PID of currently executing process, used as key by TLB)  
`cr2` = ISR (interrupt status register, holds which interrupts are active)  
`cr3` = IMR (interrupt mask register, enables various interrupts. Top bit enables/disables all interrupts)   
`cr4` = EPC (exceptional PC, pc is placed here after interrupt, syscall, or exception)  
`cr5` = FLG (flags register)  
`cr6` = EFG (exceptional flags). Flags are placed here when an interrupt, syscall, or exception happens  
`cr7` = TLB (address is placed here when it causes a TLB miss)  
`cr8` = KSP (kernel stack pointer, stack is set here on a user -> kernel switch)  
`cr9` = CID (Read-only core ID register)  
`cr10` = MBI (maibox in, data appears here when an IPI happens)  
`cr11` = MBO (mailbox out, write data here and do an IPI to send the value to another core)  
`cr12` = ISP (interrupt stack pointer, used when handling interrupts or kernel TLB misses)

On interrupt/exception/syscall, top bit of IMR is unset to disable further interrupts. The kernel must set it after saving pc and flags to enable nested interrupts

OS page size: 4KB  
Nexys a7 has 128MiB of memory, so this means we need to map 32 bit addresses to 27 bit addresses.  
The TLB will do this by looking at the top 20 bits of a 32 bit address and the 32 bit process ID and returning a 15 bit number.   
The bottom 12 bits of the address pass through the TLB, creating an 27 bit address.  
When in user mode, all addresses are mapped by the TLB.
When in kernel mode, the bottom 128MiB of address space does not go through the TLB (0x00000000 - 0x07FFFFFF).

## User Instructions:

### 3 Register ALU Instructions

`rA` is destination, `rB` and `rC` are sources

Opcode is 00000

(x -> unused bits)

#### Bitwise logic:  
`00000aaaaabbbbbxxxxxxx00000ccccc` - `and  rA, rB, rC`  
`00000aaaaabbbbbxxxxxxx00001ccccc` - `nand rA, rB, rC`  
`00000aaaaabbbbbxxxxxxx00010ccccc` - `or   rA, rB, rC`  
`00000aaaaabbbbbxxxxxxx00011ccccc` - `nor  rA, rB, rC`  
`00000aaaaabbbbbxxxxxxx00100ccccc` - `xor  rA, rB, rC`  
`00000aaaaabbbbbxxxxxxx00101ccccc` - `xnor rA, rB, rC`  
`00000aaaaaxxxxxxxxxxxx00110ccccc` - `not  rA, rC`  

#### Shifts:  
`00000aaaaabbbbbxxxxxxx00111ccccc` - `lsl  rA, rB, rC` (logical shift left)  
`00000aaaaabbbbbxxxxxxx01000ccccc` - `lsr  rA, rB, rC` (logical shift right)  
`00000aaaaabbbbbxxxxxxx01001ccccc` - `asr  rA, rB, rC` (arithmetic shift right)  
`00000aaaaabbbbbxxxxxxx01010ccccc` - `rotl rA, rB, rC` (rotate left)  
`00000aaaaabbbbbxxxxxxx01011ccccc` - `rotr rA, rB, rC` (rotate right)  
`00000aaaaabbbbbxxxxxxx01100ccccc` - `lslc rA, rB, rC` (shift left through carry)  
`00000aaaaabbbbbxxxxxxx01101ccccc` - `lsrc rA, rB, rC` (shift right through carry)  

#### Arithmetic:  
`00000aaaaabbbbbxxxxxxx01110ccccc` - `add  rA, rB, rC`  
`00000aaaaabbbbbxxxxxxx01111ccccc` - `addc rA, rB, rC` (add with carry)  
`00000aaaaabbbbbxxxxxxx10000ccccc` - `sub  rA, rB, rC`  
`00000aaaaabbbbbxxxxxxx10001ccccc` - `subb rA, rB, rC` (subtract with borrow)    
`00000aaaaaxxxxxxxxxxxx10010ccccc` - `sxtb rA, rC` (sign extend byte)  
`00000aaaaaxxxxxxxxxxxx10011ccccc` - `sxtd rA, rC` (sign extend double)  
`00000aaaaaxxxxxxxxxxxx10100ccccc` - `tncb rA, rC` (truncate to byte)  
`00000aaaaaxxxxxxxxxxxx10101ccccc` - `tncd rA, rC` (truncate to double)  

Plenty of instruction space to expand this over time - floating point stuff will likely be next  

### ALU immediate instructions

`rA` is destination, `rB` is source, `i` is immediate

Opcode is 00001

(x -> unused bits)

#### Bitwise logic:   
yy is 2 bit code used to decode immediate  
i is 8 bit immediate

i is decoded as (i << (8 * y))

So i = 0x0F and y = 0 decodes as  0x0000000F  
But i = 0x0F and y = 2 decodes as 0x000F0000

`00001aaaaabbbbb00000xxyyiiiiiiii` - `and  rA, rB, i`  
`00001aaaaabbbbb00001xxyyiiiiiiii` - `nand rA, rB, i`     
`00001aaaaabbbbb00010xxyyiiiiiiii` - `or   rA, rB, i`   
`00001aaaaabbbbb00011xxyyiiiiiiii` - `nor  rA, rB, i`   
`00001aaaaabbbbb00100xxyyiiiiiiii` - `xor  rA, rB, i`  
`00001aaaaabbbbb00101xxyyiiiiiiii` - `xnor rA, rB, i`  
`00001aaaaaxxxxx00110xxyyiiiiiiii` - `not  rA, i`  

#### Shifts:  
`i` is 5 bit immediate

`00001aaaaabbbbb00111xxxxxxxiiiii` - `lsl  rA, rB, i`  
`00001aaaaabbbbb01000xxxxxxxiiiii` - `lsr  rA, rB, i`  
`00001aaaaabbbbb01001xxxxxxxiiiii` - `asr  rA, rB, i`  
`00001aaaaabbbbb01010xxxxxxxiiiii` - `rotl rA, rB, i`  
`00001aaaaabbbbb01011xxxxxxxiiiii` - `rotr rA, rB, i`  
`00001aaaaabbbbb01100xxxxxxxiiiii` - `lslc rA, rB, i`    
`00001aaaaabbbbb01101xxxxxxxiiiii` - `lsrc rA, rB, i`  

#### Arithmetic:  
`i` is 12 bit immediate, sign extended to 32 bits  
`00001aaaaabbbbb01110iiiiiiiiiiii` - `add  rA, rB, i`     
`00001aaaaabbbbb01111iiiiiiiiiiii` - `addc rA, rB, i`  
`00001aaaaabbbbb10000iiiiiiiiiiii` - `sub  rA, rB, i` - does `rA <- (i - rB)`, so this is different from `add rA, rB, -i`  
`00001aaaaabbbbb10001iiiiiiiiiiii` - `subb rA, rB, i`   

some instruction space to expand this over time

### lui (Load Upper Immediate)

Opcode is 00010

`i` is 22 bit immediate, shifted left by 10 to make a 32 bit value

`rA` is target

Use with addi to move any 32 bit value into a register

`00010aaaaaiiiiiiiiiiiiiiiiiiiiii` - `lui rA, i`

### Assembler Macros (Non-ISA)

The assembler provides `movi` as a macro that expands to `lui` + `addi` to
materialize a 32-bit constant. `movi`/`movu`/`movl` are assembler-only; the
hardware only sees the underlying `lui`/`addi` instructions.

When the `movi` immediate is a label, the assembler does not materialize the
absolute label address. Instead, it encodes a PC-relative offset:

- `movi rA, label` loads `rA = label - (pc_of_movu + 12)`.
- `pc_of_movu` is the address of the `lui` emitted by `movi`.

This offset is chosen so that a relative branch immediately after `movi`
reaches the label:

```
movi rA, label
br r0, rA
```

Here `br` executes at `pc_of_movu + 8`, so `br` adds `pc + 4` and reaches
`label`. If you need an absolute address for a label, add the current
`pc + 4` to the offset (for example, use `br rTmpPc, r0` to capture
`pc + 4` into a register, then `add rA, rA, rTmpPc`).

### Memory 

sw - store word  
lw - load word

#### Absolute Addressing:  
Opcode is 00011

`rA` is data, `rB` is base, `y` is offset type, `z` is shift amount (0 to 3), `i` is 12 bit immediate, sign extended to 32 bits

y = 0 - signed offset  
y = 1 - preincrement  
y = 2 - postincrement

`00011aaaaabbbbb0yyzziiiiiiiiiiii` - `swa rA, [rB], i`  
`00011aaaaabbbbb1yyzziiiiiiiiiiii` - `lwa rA, [rB], i` 

#### PC-Relative Addressing:  
Opcode is 00100

`rA` is data, `rB` is base, `i` is 16 bit immediate, sign extended to 32 bits

Address gets added to PC before it's used

`00100aaaaabbbbb0iiiiiiiiiiiiiiii` - `sw rA, [rB], i`  
`00100aaaaabbbbb1iiiiiiiiiiiiiiii` - `lw rA, [rB], i` 

#### PC-Relative Addressing (immediate):  
Opcode is 00101

`rA` is data, `i` is 21 bit immediate, sign extended to 32 bits

Address gets added to PC before it's used

`00101aaaaa0iiiiiiiiiiiiiiiiiiiii` - `sw rA, [i]`  
`00101aaaaa1iiiiiiiiiiiiiiiiiiiii` - `lw rA, [i]` 

#### Store/load double:
Same encoding as above, but opcodes are 00110 - 01000  

double = 2 bytes

`sd rA, [rB], i`    
`ld rA, [rB], i`  

#### Store/load byte:
Same encoding as above, but opcodes are 01001 - 01011

`sb rA, [rB], i`  
`lb rA, [rB], i`  

### Immediate Branches

Opcode is 01100

5 bit branch code determines which condition to use. i is 22 bit immediate, sign extended to 32 bit    
If condition is met, branches to pc + 4 * (i + 1)

`0110000000iiiiiiiiiiiiiiiiiiiiii` - `br i`   (unconditional branch)  
`0110000001iiiiiiiiiiiiiiiiiiiiii` - `bz i`   (branch if zero)  
`0110000010iiiiiiiiiiiiiiiiiiiiii` - `bnz i`  (branch if nonzero)  
`0110000011iiiiiiiiiiiiiiiiiiiiii` - `bs i`   (branch if sign [negative])  
`0110000100iiiiiiiiiiiiiiiiiiiiii` - `bns i`  (branch not sign [not negative])  
`0110000101iiiiiiiiiiiiiiiiiiiiii` - `bc i`   (branch if carry)  
`0110000110iiiiiiiiiiiiiiiiiiiiii` - `bnc i`  (branch if not carry)  
`0110000111iiiiiiiiiiiiiiiiiiiiii` - `bo i`   (branch if overflow)  
`0110001000iiiiiiiiiiiiiiiiiiiiii` - `bno i`  (branch if not overflow)  
`0110001001iiiiiiiiiiiiiiiiiiiiii` - `bps i`  (branch if positive)  
`0110001010iiiiiiiiiiiiiiiiiiiiii` - `bnps i` (branch if not positive)  
`0110001011iiiiiiiiiiiiiiiiiiiiii` - `bg i`   (branch if greater [signed])  
`0110001100iiiiiiiiiiiiiiiiiiiiii` - `bge i`  (branch if greater or equal [signed])  
`0110001101iiiiiiiiiiiiiiiiiiiiii` - `bl i`   (branch if less [signed])  
`0110001110iiiiiiiiiiiiiiiiiiiiii` - `ble i`  (branch if less or equal [signed])  
`0110001111iiiiiiiiiiiiiiiiiiiiii` - `ba i`   (branch if above [unsigned])  
`0110010000iiiiiiiiiiiiiiiiiiiiii` - `bae i`  (branch if above or equal [unsigned])  
`0110010001iiiiiiiiiiiiiiiiiiiiii` - `bb i`   (branch if below [unsigned])  
`0110010010iiiiiiiiiiiiiiiiiiiiii` - `bbe i`  (branch if below or equal [unsigned])  

Leaves room if more branch conditions are ever needed

### Absolute Register Branches

Opcode is 01101

Branch and link register

5 bit branch code determines which condition to use.
If condition is met, branches to rB and stores pc + 4 in rA (set rA as r0 if you don’t want to save it)

`0110100000xxxxxxxxxxxxaaaaabbbbb` - `bra rA, rB`  (unconditional branch)  
`0110100001xxxxxxxxxxxxaaaaabbbbb` - `bza rA, rB`  (branch if zero)  
`0110100010xxxxxxxxxxxxaaaaabbbbb` - `bnza rA, rB` (branch if nonzero)  
`0110100011xxxxxxxxxxxxaaaaabbbbb` - `bsa rA, rB`  (branch if sign [negative])  
`0110100100xxxxxxxxxxxxaaaaabbbbb` - `bnsa rA, rB` (branch not sign [not negative])  
`0110100101xxxxxxxxxxxxaaaaabbbbb` - `bca rA, rB`  (branch if carry)  
`0110100110xxxxxxxxxxxxaaaaabbbbb` - `bnca rA, rB` (branch if not carry)  
`0110100111xxxxxxxxxxxxaaaaabbbbb` - `boa rA, rB`  (branch if overflow)  
`0110101000xxxxxxxxxxxxaaaaabbbbb` - `bnoa rA, rB` (branch if not overflow)  
`0110101001xxxxxxxxxxxxaaaaabbbbb` - `bpa rA, rB`  (branch if positive)  
`0110101010xxxxxxxxxxxxaaaaabbbbb` - `bnpa rA, rB` (branch if not positive)  
`0110101011xxxxxxxxxxxxaaaaabbbbb` - `bga rA, rB`  (branch if greater [signed])  
`0110101100xxxxxxxxxxxxaaaaabbbbb` - `bgea rA, rB` (branch if greater or equal [signed])  
`0110101101xxxxxxxxxxxxaaaaabbbbb` - `bla rA, rB`  (branch if less [signed])  
`0110101110xxxxxxxxxxxxaaaaabbbbb` - `blea rA, rB` (branch if less or equal [signed])  
`0110101111xxxxxxxxxxxxaaaaabbbbb` - `baa rA, rB`  (branch if above [unsigned])  
`0110110000xxxxxxxxxxxxaaaaabbbbb` - `baea rA, rB` (branch if above or equal [unsigned])  
`0110110001xxxxxxxxxxxxaaaaabbbbb` - `bba rA, rB`  (branch if below [unsigned])  
`0110110010xxxxxxxxxxxxaaaaabbbbb` - `bbea rA, rB` (branch if below or equal [unsigned])  

Leaves room if more branch conditions are ever needed

### Relative Register Branches

Opcode is 01110

Branch and link register

5 bit branch code determines which condition to use.
If condition is met, branches to rB + pc + 4 and stores pc + 4 in rA (set rA as r0 if you don’t want to save it)

`0111000000xxxxxxxxxxxxaaaaabbbbb` - `br rA, rB`   (unconditional branch)  
`0111000001xxxxxxxxxxxxaaaaabbbbb` - `bz rA, rB`   (branch if zero)  
`0111000010xxxxxxxxxxxxaaaaabbbbb` - `bnz rA, rB`  (branch if nonzero)  
`0111000011xxxxxxxxxxxxaaaaabbbbb` - `bs rA, rB`   (branch if sign [negative])  
`0111000100xxxxxxxxxxxxaaaaabbbbb` - `bns rA, rB`  (branch not sign [not negative])  
`0111000101xxxxxxxxxxxxaaaaabbbbb` - `bc rA, rB`   (branch if carry)  
`0111000110xxxxxxxxxxxxaaaaabbbbb` - `bnc rA, rB`  (branch if not carry)  
`0111000111xxxxxxxxxxxxaaaaabbbbb` - `bo rA, rB`   (branch if overflow)  
`0111001000xxxxxxxxxxxxaaaaabbbbb` - `bno rA, rB`  (branch if not overflow)  
`0111001001xxxxxxxxxxxxaaaaabbbbb` - `bp rA, rB`   (branch if positive)  
`0111001010xxxxxxxxxxxxaaaaabbbbb` - `bnp rA, rB`  (branch if not positive)  
`0111001011xxxxxxxxxxxxaaaaabbbbb` - `bg rA, rB`   (branch if greater [signed])  
`0111001100xxxxxxxxxxxxaaaaabbbbb` - `bge rA, rB`  (branch if greater or equal [signed])  
`0111001101xxxxxxxxxxxxaaaaabbbbb` - `bl rA, rB`   (branch if less [signed])  
`0111001110xxxxxxxxxxxxaaaaabbbbb` - `ble rA, rB`  (branch if less or equal [signed])  
`0111001111xxxxxxxxxxxxaaaaabbbbb` - `ba rA, rB`   (branch if above [unsigned])  
`0111010000xxxxxxxxxxxxaaaaabbbbb` - `bae rA, rB`  (branch if above or equal [unsigned])  
`0111010001xxxxxxxxxxxxaaaaabbbbb` - `bb rA, rB`   (branch if below [unsigned])  
`0111010010xxxxxxxxxxxxaaaaabbbbb` - `bbe rA, rB`  (branch if below or equal [unsigned]) 

### Syscalls

Opcode is 01111

List will expand as we go

i is 8 bit immediate specifying which exception to raise

`01111xxxxxxxxxxxxxxxxxxxiiiiiiii`

For now, we’ll start with supporting

`01111xxxxxxxxxxxxxxxxxxx00000000` - `sys EXIT`, returning control from the user code to the OS

### Atomics

The ISA supports atomic fetch add and atomic swap instructions for all three addressing modes, but only for 32 bit data

#### Fetch Add (Absolute Addressing):  
Opcode is 10000

`rA` is destination reg, `rC` is data, `rB` is base, `i` is 12 bit immediate, sign extended to 32 bits

`10000aaaaacccccbbbbbiiiiiiiiiiii` - `fada rA, rC, [rB, i]`  

#### Fetch Add (PC-Relative Addressing):  
Opcode is 10001

`rA` is destination reg, `rC` is data, `rB` is base, `i` is 12 bit immediate, sign extended to 32 bits  

Address gets added to PC before it's used

`10001aaaaacccccbbbbbiiiiiiiiiiii` - `fad rA, rC, [rB, i]`  

#### Fetch Add (PC-Relative Addressing, immediate):  
Opcode is 10010

`rA` is destination reg, `rC` is data, `i` is 17 bit immediate, sign extended to 32 bits
Address gets added to PC before it's used

`10010aaaaaccccciiiiiiiiiiiiiiiii` - `fad rA, rC, [i]`  

#### Swap (Absolute Addressing):  
Opcode is 10011

`rA` is destination reg, `rC` is data, `rB` is base, `i` is 12 bit immediate, sign extended to 32 bits

`10011aaaaabbbbbccccciiiiiiiiiiii` - `swpa rA, rC, [rB, i]`  

#### Swap (PC-Relative Addressing):  
Opcode is 10100

`rA` is destination reg, `rC` is data, `rB` is base, `i` is 12 bit immediate, sign extended to 32 bits  

Address gets added to PC before it's used

`10100aaaaabbbbbccccciiiiiiiiiiii` - `swp rA, rC, [rB, i]`  

#### Swap (PC-Relative Addressing, immediate):  
Opcode is 10101

`rA` is destination reg, `rC` is data, `i` is 17 bit immediate, sign extended to 32 bits

Address gets added to PC before it's used

`10101aaaaaccccciiiiiiiiiiiiiiiii` - `swp rA, rC, [i]`  

### adpc

`rA` is destination register, `i` is a 22 bit signed immediate.

does `rA <- pc + i + 4`, converting pc-relative addresses into absolute addresses.

`10110aaaaaiiiiiiiiiiiiiiiiiiiiii` - `adpc rA, i`

## Privileged Instructions:

Opcode - 11111
All share opcode, distinguished by 5 bit ID following rB

### Tlb reads/writes/clear   
ID - 00000

TLB reads and writes concatenate the value in the PID register to the key  

`11111aaaaabbbbb0000000xxxxxxxxxx` - `tlbr rA, rB` - if rB exists in tlb, put its map in rA, otherwise put 0 in rA

`11111aaaaabbbbb0000001xxxxxxxxxx` - `tlbw rA, rB` - write a new tlb entry mapping rB to rA

`11111xxxxxbbbbb0000010xxxxxxxxxx` - `tlbi rB` - if rB exists in tlb, invalidate its entry

`11111xxxxxxxxxx0000011xxxxxxxxxx` - `tlbc` - clear tlb

#### TLB Structure

A TLB entry looks like this: `PID (32 bits) | VPN (20 bits) || PPN (15 bits) | Flags (12 bits)`  
The part to the left of the `||` is the key, the part on the right is the value.

For now, only the bottom 5 bits of the flags are used. They are `G U X W R` (with `R` being in bit 0)  
G - global (if set, any PID can match this entry)  
U - user (if set, this entry becomes valid in user mode)  
X - executable  
W - writable  
R - readable   

`tlbr rA, rB` will use the PID and `(rB & 0xFFFFF000)` as a key and put the value in `rA`  
`tlbw rA, rB` will use the PID and `(rB & 0xFFFFF000)` as a key and store `(rA & 0x7FFFFFF)` as the value in the TLB

### Move to/from control regs
ID - 00001

`11111aaaaabbbbb0000100xxxxxxxxxx` - `crmv crA, rB` - move rB into control register crA  
`11111aaaaabbbbb0000101xxxxxxxxxx` - `crmv rA, crB` - move control register crB into rA  
`11111aaaaabbbbb0000110xxxxxxxxxx` - `crmv crA, crB` - move control register crB into control register crA   
`11111aaaaabbbbb0000111xxxxxxxxxx` - `crmv rA, rB` - move rB into rA (only use is to read/write r31 when in kernel mode)   

### Set mode - sleep, halt
ID - 00010

`11111xxxxxxxxxx0001001xxxxxxxxxx` - `mode sleep` - (awakened by interrupt)  
`11111xxxxxxxxxx0001010xxxxxxxxxx` - `mode halt` - (only way to exit is reset)

### Return from exception/interrupt
ID - 00011

`11111xxxxxxxxxx000110xxxxxxxxxxx` - `rfe` - (return from exception) update kmode and jump to EPC, set flags to efg  
`11111xxxxxxxxxx000111xxxxxxxxxxx` - `rfi` - (return from interrupt) update kmode and jump to EPC, set flags to efg, and reenable interrupts  
`11111xxxxxxxxxx00101xxxxxxxxxxx` - `rft` - (return from kernel TLB miss) update kmode and jump to EPC, set flags to efg  

Leaves lots of unused opcodes, so the ISA can be expanded over time

### Inter-processor interrupts
ID - 00100

`11111aaaaaxxxxx001000xxxxxxxxxnn` - `ipi rA, n` - interrupt core n, put success code in rA (1 => success, 0 => failure)  

`11111aaaaaxxxxx001001xxxxxxxxxxx` - `ipi rA, all` - interrupt all other cores, put bitmap of successes in rA

## Exceptions:

All exceptions, interrupts, and syscalls cause the processor to enter kernel mode and jump to the address specified in the interrupt vector table (IVT).

### Exception types:

#### Index into interrupt vector table

```
sys EXIT                       := 0x01  
Invalid instruction exception  := 0x80  
Privileges exception           := 0x81  
Tlb umiss exception            := 0x82  
Tlb kmiss exception            := 0x83  
Misaligned pc exception        := 0x84  
Timer interrupt                := 0xF0   
Keyboard interrupt             := 0xF1  
UART RX interrupt              := 0xF2  
SD card 0 interrupt            := 0xF3  
VGA vblank interrupt           := 0xF4  
IPI interrupt                  := 0xF5  
SD card 1 interrupt            := 0xF6
```

#### Interrupt bits in IMR/ISR
```
Timer interrupt      := 0x00000001  
Keyboard interrupt   := 0x00000002  
UART RX interrupt    := 0x00000004    
SD card 0 interrupt  := 0x00000008  
VGA vblank interrupt := 0x00000010  
IPI interrupt        := 0x00000020  
SD card 1 interrupt  := 0x00000040
```

Timer interrupt goes to all cores, IPI goes to the cores specified by the instruction. KB, UART, SD card 0, SD card 1, and VGA interrupts are sent to a single core whenever they happen. The core is chosen with a round-robin distribution.
