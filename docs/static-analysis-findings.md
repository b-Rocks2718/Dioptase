# Initial static analysis findings

## Follow-up: C/Rust CI gate

`make analysis-software` now reports clean for both C tools and both Rust
emulators under the documented CI lint policy. Verilog remains outside CI and
was not modified in this follow-up.

Fixed the assembler preprocessing allocation-failure cleanup and allocation
element sizes, the compiler's leaked array dimensions on parse backtracking,
and four dead tail-pointer stores after final initializer padding. Rust debugger
tests now construct their candidate vectors directly; the full emulator's IVT
range uses `Range::contains`, retaining exactly the same interval. The IVT range
was checked against `docs/mem_map.md`'s `0x0000000 - 0x00003FF` section; no ISA,
ABI, privilege, or MMIO behavior changed.

Verified fatal compiler helpers and parser/label-list invariants are modeled
only for Clang analysis. Style and complexity Clippy suggestions are excluded
by policy, separately from verified analyzer false positives. See
[the current setup and suppression rationale](static-analysis.md).

Four regression/runner tests pass. Both allocation regression harnesses also
fail against the original source, demonstrating they detect the bugs. The
assembler/compiler CI scripts now run those allocation regressions and Clang
analysis. Both emulator CI scripts run Clippy. The standalone submodule
workflows and hosted root `software-ci.yml` both use those same scripts.

Follow-up verification: assembler 47/47 and compiler 228/228 in both debug and
release builds; simple emulator 62 unit + 1 integration test; full emulator 121
unit + 1 integration test. All passed. The workflow structure was later rebased
onto the hosted software CI; that updated remote workflow has not yet been run.

## Original run (historical)

Run on 2026-09-18 using Clang 18.1.3, Clippy 0.1.97, and Verilator 5.020.
Reproduce with the commands in [static-analysis.md](static-analysis.md).
Full diagnostic paths and source excerpts are in `build/static-analysis/*.log`.
Counts below describe this checkout, including pre-existing local changes; they
are diagnostics, not counts of confirmed bugs. At that stage no product code
had been changed. The fixes above supersede the original recommendations below.

| Component | Initial diagnostics |
| --- | --- |
| Assembler | 4 Clang analyzer findings |
| C compiler | 60 Clang analyzer findings |
| Simple emulator | 18 Clippy diagnostics across application/test targets |
| Full emulator | 124 Clippy diagnostics across application/test targets |
| Simple CPU | 28 Verilator warnings |
| Full CPU, test configuration | 99 Verilator warnings |
| Full CPU, OS configuration | 100 Verilator warnings |

## Findings worth reviewing first

- **Assembler allocation-failure leak:** `Dioptase-Assembler/src/preprocessor.c:353`
  returns NULL if allocation of the current file's result fails, without freeing
  `result_list` or earlier results. This cleanup omission is visible in the
  source. Free the previously allocated results and the list on this path.
- **Assembler allocation sizes:** `src/main.c:185` and `src/preprocessor.c:339`
  allocate arrays of character pointers using `sizeof(char**)`. Use
  `sizeof(*files)` and `sizeof(*result_list)` respectively. This is a type/intent
  mismatch; it is not evidence of an undersized allocation on the current host.
- **Simple CPU memory model inconsistency:**
  `Dioptase-CPUs/Dioptase-Pipe-Simple/src/mem.v:34` and subsequent accesses index a
  65,536-word array with only `addr[15:2]` (14 bits, selecting 16,384 words).
  Its comment also claims 64K words. Resolve the intended address range against
  the architecture contract before changing the index, array size, or comment.
- **Full CPU sequential blocking assignments:** Verilator reports 13 `BLKSEQ`
  warnings per configuration in `mem.v` and `sd_dma_controller.v`. Review whether
  each assignment updates persistent state or is a same-process temporary.
  Do not mechanically replace every `=` with `<=`: that can alter evaluation
  order and hardware behavior. Repository HDL rules also need to be considered.

## Findings requiring qualification

- The compiler findings comprise 51 possible null dereferences, four possible
  divisions by zero, four dead stores, and one possible allocation leak.
  At least some are analyzer-model limitations: for example,
  `TAC_interpreter.c:270` follows a NULL check calling `tac_interp_error`, which
  terminates through `exit`. The helper lacks an explicit non-returning
  declaration. Consider a portable C non-returning annotation supported by the
  project's host and self-hosted compiler paths, then rerun before treating
  these reports as runtime bugs. Other findings still need individual review.
- The assembler's `label_list.c:37` zero-size allocation report assumes a zero
  capacity on entry to append. The constructor normalizes zero capacity to 16.
  Check all construction paths and capacity-overflow handling before deciding
  whether this is reachable. The analyzer does not establish that it is.
- The Rust reports largely suggest style, simpler expressions, or clearer
  control flow. For example, both emulators' arithmetic-shift expressions trigger
  precedence warnings. These do not by themselves demonstrate incorrect ISA
  behavior. Parenthesizing intended operations is a reasonable clarity fix.
- Most Verilog reports concern unused signals, names, or hidden declarations.
  Some signals are intentionally unused in particular configurations. Review
  before removing them or introducing narrowly scoped suppressions.

## Verification of the tooling change

Before and after results were identical:

| Suite | Result |
| --- | --- |
| Assembler `make test` | 47/47 |
| Compiler `make test` | 228/228 |
| Simple emulator `cargo test` | 62 unit + 1 integration test passed |
| Full emulator `cargo test` | 121 unit + 1 integration test passed |
| Simple CPU `make test` | 11/65; pre-existing failures |
| Full CPU `make test-verilator` | 85/98; pre-existing failures |

The initial Cargo Snap invocation failed; the Rust suites and compiler suite
were rerun successfully with the separate native Rust toolchain on PATH.
The CPU failures were not diagnosed or changed as part of this setup.
Local baseline logs are in `/tmp/dioptase-analysis-before/` and
`/tmp/dioptase-analysis-before-rust/`; after logs are in
`/tmp/dioptase-analysis-after/` (temporary files, not committed artifacts).

The new runner was also exercised with controlled clean output, a warning,
a nonzero tool exit followed by another command, and a missing executable.
These checks verified continuation, log capture, JSON summaries, and failure
exit status. `make` still defaults to `all`; existing CI was not modified.
