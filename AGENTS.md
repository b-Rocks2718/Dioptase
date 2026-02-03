# AGENTS.md

## Global Instructions for Codex

These rules apply to **all code written or modified by Codex** in this repository.
Violating any rule below is considered a bug.

---

## Project Context

This repository is part of a **custom computer architecture / operating system / hardware stack**.

Codex must:
- Not assume x86, ARM, POSIX, or Linux behavior
- Treat all architectural behavior as **explicitly specified**
- Avoid guessing when documentation is silent

---

## Canonical Architecture & ISA Documentation

The authoritative documentation for this project lives at the following paths:

### ISA Specification
./docs/ISA

### ABI / Calling Convention
./docs/abi.md

### Assembler Syntax
./Dioptase-Assembler/docs/syntax.md

### OS / Kernel Architecture

Preemption structure:
thread A running -> interrupt, switch to pit handler -> block, context switch to thread B

later...
thread B blocks for whatever reason -> context switch to thread A -> thread A returns from pit handler -> thread A running again

pit_handler saves/restores caller-saved registers, context_switch saves/restores callee-saved registers. This DOES NOT clobber registers, because the compiler will save callee-saved register before calling context_switch and restore them after.

thread state:
```
struct Fun {
  void (*func)(void *);
  void *arg;
};

struct TCB {

  unsigned r1; // offset 0
  unsigned r2; // offset 4
  unsigned r3; // offset 8
  unsigned r4; // offset 12
  unsigned r5; // offset 16
  unsigned r6; // offset 20
  unsigned r7; // offset 24
  unsigned r8; // offset 28
  unsigned r9; // offset 32
  unsigned r10; // offset 36
  unsigned r11; // offset 40
  unsigned r12; // offset 44
  unsigned r13; // offset 48
  unsigned r14; // offset 52
  unsigned r15; // offset 56
  unsigned r16; // offset 60
  unsigned r17; // offset 64
  unsigned r18; // offset 68
  unsigned r19; // offset 72
  unsigned r20; // offset 76
  unsigned r21; // offset 80
  unsigned r22; // offset 84
  unsigned r23; // offset 88
  unsigned r24; // offset 92
  unsigned r25; // offset 96
  unsigned r26; // offset 100
  unsigned r27; // offset 104
  unsigned r28; // offset 108

  unsigned sp;  // offset 112
  unsigned bp;  // offset 116

  unsigned flags; // offset 120
  unsigned ret_addr; // offset 124
  unsigned psr;      // offset 128
  unsigned imr;      // offset 132

  unsigned *stack;
  struct Fun *thread_fun;

  struct TCB* next;
};
```

Nested interrupts are prevented because interrupts are disabled when an interrupt happens. They are reenabled when the interrupted thread context switches to a thread that should have interrupts enabled (by updating IMR), or when the interrupt handler returns (with an rfi instruction).

Context switching from within the pit handler is possible without messing up the threads interrupt state by saving the imr in the thread state.

### Hardware Interfaces (MMIO / Devices)
./docs/mem_map.md

These documents are the **single source of truth** for all architecturally
visible behavior.

---

### Scope
This section applies to:
- ./Dioptase-Assembler/** 
- ./Dioptase-Languages/**
- any shared libraries used by those tools

### Portability rules
Do not use gcc-specific or OS-specific features unless necessary, and explain why if necessary. 
Use of these features will mean the compiler requires additional work to port to the Dioptase system.  

---

## Documentation Precedence

If there is a conflict between:
1. Architecture / ISA documentation
2. Existing code
3. Codex assumptions

The documentation **always takes precedence**.

Codex must surface conflicts explicitly and must not resolve them silently.

---

## Required Consultation Behavior

Before implementing or modifying any **architecturally visible behavior**, Codex must:

- Identify which documentation files apply
- State which sections were relied upon
- Explicitly note any ambiguities or unspecified behavior

If behavior is not specified:
- Codex must not guess
- Codex must mark it as *unspecified* or *implementation-defined*
- Codex may suggest options but must not choose silently

---

## Commenting Policy by Component

Commenting requirements depend on the part of the codebase:

### Kernel / OS Code / Hardware Verilog
(Applies to paths matching: Dioptase-OS/, Dioptase-CPUs/)

- Extremely careful and explicit comments are required.
- All non-trivial functions must document:
  - Preconditions and postconditions
  - Invariants
  - CPU state assumptions (mode, interrupts, MMU, core count)
- Complex control flow must be explained step-by-step.
- Comments should assume a future reader debugging subtle kernel bugs.

### Compiler / Emulator / Assembler Code
(Applies to paths matching: Dioptase-Languages/, Dioptase-Assembler/, Dioptase-Emulator/)

- Clear and reasonably detailed comments are required.
- Focus on explaining algorithms, data structures, and non-obvious logic.
- Avoid over-commenting straightforward code.

### Test Code
(Applies to paths matching: tests/)

- Minimal comments are preferred, unless the test complexity justifies detailed comments
- Comments should explain:
  - What behavior is being tested
  - Why the test exists (especially for edge cases)
- Do not comment obvious assertions or boilerplate.

## ABI & Calling Conventions

- No code may assume a calling convention unless explicitly documented.
- Register usage (caller-saved vs callee-saved) must be stated.
- Stack layout assumptions must be documented.
- Thread-local storage usage must be explicit.

---

## Privilege & Mode Transitions

- All user <-> kernel transitions must be documented.
- Trap, interrupt, and syscall entry state must be described.
- Code must explicitly state whether it executes in user or kernel mode.

---

## Memory Model & Concurrency

- The memory model is **sequentially consistent** unless documented otherwise.
- All concurrent code must explicitly document:
  - Atomicity requirements
  - Ordering assumptions
- Codex must not introduce architecture-specific or relaxed atomics.

---

## Hardware / Software Contracts

Any hardware-visible interface must document:

- Address ranges
- Side effects of reads and writes
- Timing and ordering requirements
- Ownership and lifecycle of shared buffers

---

## Error Messages & Diagnostics

Error messages must be informative and actionable.

### Kernel / OS Code

- Error messages must include:
  - The subsystem or component name
  - The operation that failed
  - Relevant identifiers (e.g. PID, address, register, device, syscall)
- Messages should provide enough context to debug without a debugger when possible.
- Silent failure or generic messages (e.g. "error occurred") are forbidden.

### Compiler / Emulator / Assembler Code

- Errors must clearly state:
  - What was expected
  - What was observed
  - Where the error occurred (file, line, instruction, or input)
- Prefer structured errors over plain strings when feasible.

### Test Code

- Assertion messages should explain:
  - What behavior is being tested
  - Why the failure indicates a bug
- Avoid redundant or boilerplate assertion messages.

Error messages are part of the interface and must be treated as such.

Placeholder or vague error messages (e.g. "TODO", "unimplemented", "should not happen")
are forbidden unless explicitly justified.

---

## Constants & Magic Numbers

- All constants must be named and justified.
- Magic numbers without architectural justification are forbidden.

---

## Code Documentation Requirements

- All non-trivial code must be commented.
- Comments must explain **why**, not just **what**.
- Every function, struct, class, module, or HDL block must include:
  - Purpose
  - Inputs and outputs
  - Important invariants or assumptions

Large additions must include a top-level design comment.

---

## Proactive Review & Quality Enforcement

Codex must actively review existing code and documentation.

If Codex notices:
- Bugs or likely bugs
- Untested or poorly tested behavior
- Missing, unclear, or misleading comments
- Underspecified or ambiguous behavior
- Inconsistencies between documentation and implementation
- Uninformative error messages

Codex must:
- Call out the issue explicitly
- Explain why it is a problem
- Suggest concrete fixes or improvements

---

## Test Verification Requirements

When modifying or adding code, Codex must:

- Identify the relevant test command(s), such as:
  - `make test`
  - `cargo test`
- Run the relevent command BEFORE and AFTER any changes

If the modification broke previously working tests:
- Codex must revise its changes or explain why it needs to break existing tests

If tests exist for the modified behavior:
- Codex must ensure changes are compatible with those tests.

If no tests exist for the modified behavior:
- Codex should suggest appropriate tests and where they should live.
  
---

## Test Integrity Rules

Tests must validate correctness, not accommodate bugs.

Codex must NOT:
- Modify tests solely to make existing failures pass
- Weaken assertions to hide incorrect behavior
- Change expected values without explaining why the behavior is correct

If Codex encounters a failing test:
- Prefer fixing the underlying code
- If the test is incorrect, Codex must:
  - Explain why the test is wrong
  - Propose the corrected expected behavior
  - Clearly justify the change

---

## HDL / Verilog Rules (if applicable)

- Clock domains and reset behavior must be documented.
- Pipeline stages must be explicitly labeled.
- Non-blocking assignments must be used for sequential logic.
- Timing assumptions must be explicit.

---

## Cross-Component Consistency

Any ISA-visible change affects:

- Assembler
- Emulator(s)
- Hardware implementation(s)
- OS kernel

Codex must identify all affected components when making such changes.

---

## Final Rule

If code cannot be adequately documented or justified,
Codex must explain why **before** writing it.
