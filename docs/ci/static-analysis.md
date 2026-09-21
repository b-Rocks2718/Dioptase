# Static analysis

Run from the repository root:

```sh
make analysis        # All checks; continues to other components after findings
make analysis-software # C and Rust only; the CI gate
make analysis-c      # Clang Static Analyzer: native assembler and C compiler
make analysis-rust   # Clippy: both emulators, including test targets
make analysis-rtl    # Verilator lint: both CPUs; full CPU test and OS variants
```

Reports go in `build/static-analysis/`: one text log per component/configuration
and a `summary.json` for the latest invocation. Logs include commands, diagnostic
locations, analyzer execution paths where available, and exit statuses. Each
selected log is overwritten; logs from unselected components may be older.
`clean` means the selected tool reported no findings, not proof of correctness.
`attention` means diagnostics or a tool failure; consult that log to distinguish
them. The command returns nonzero for either and still runs the remaining checks.

## Requirements

- Python 3.8 or newer and Make.
- Clang with its Static Analyzer (tested with Clang 18).
- Rust/Cargo with Clippy installed for the active toolchain, plus the host
  dependencies already needed to build the emulators. With rustup, use
  `rustup component add clippy`.
- Verilator with `--timing` support (tested with Verilator 5.020).
- Initialized submodules: `git submodule update --init --recursive`.

Tools must be on `PATH`. Executable paths can also be overridden with environment
variables `CLANG`, `CARGO`, and `VERILATOR`; these accept one executable path each,
not shell commands or flag lists. Override the Python interpreter with
`make analysis PYTHON=python3`. To put reports elsewhere:

```sh
python3 scripts/static_analysis.py all --output /tmp/dioptase-analysis
```

If the Cargo Snap launcher cannot run, put a working Rust toolchain's `bin`
directory first on `PATH`, so Cargo, rustc, and Clippy use the same toolchain.
On the machine used for initial verification this worked:

```sh
export PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH"
make analysis
```

## Coverage and limits

The C check analyzes each `src/*.c` translation unit with `-Wall -Wextra` and
Clang's default analyzer checkers. Source selection and language mode match the
native Makefiles. It does not build executables or alter existing build flags.
Analysis is per translation unit, so callers' invariants and functions defined
in other files may not be understood. Review findings before changing code.

Clippy uses `--locked --all-targets -- -D warnings -A clippy::style -A clippy::complexity`.
This gates correctness, suspicious-code, performance, and Rust compiler warnings.
Style and complexity suggestions are intentionally outside the CI policy, not
classified as bugs or false positives. For example, spelling MMIO ranges as
comparisons, separate dispatch branches with the same body but different
side-effecting conditions, and explicit returns do not warrant broad emulator
rewrites. To see the complete default lint set, run `cargo clippy --locked
--all-targets -- -D warnings` in either emulator directory.

Dependencies may need to be
downloaded on first use; Cargo also updates its normal build cache. Default
lint sets can change with toolchain updates; review new findings rather than
automatically baselining them away.

Verilator uses `--lint-only --Wall --timing --top-module dioptase`. The simple
CPU includes its timed simulation harness. The full CPU is checked with and
without `VERILATOR_TEST`, matching its test and OS Verilator configurations.
This does not cover every FPGA configuration, device testbench, or synthesis
constraint. Naming and unused-signal warnings also count as attention.

These are host development tools. The C check does not analyze the guest OS:
using host type sizes, assembly rules, or threading assumptions there would not
validate Dioptase's ABI or concurrency model. Valgrind Memcheck is configured
separately for the host-native C tools; see
[dynamic memory analysis](dynamic-analysis.md). Sanitizers, fuzzing, and formal
verification remain separate work. Existing functional test recipes are
unchanged.

## CI

Each software submodule owns its analysis in `.github/scripts/ci.sh`. The
assembler and compiler scripts run their debug/release suites, allocation
regression tests, Clang Static Analyzer, and the separately documented
Memcheck policy. Each emulator script runs Clippy plus debug/release tests.
Their standalone PR workflows and the root hosted `software-ci.yml` workflow
call the same scripts, so neither CI path can omit analysis accidentally.

The root `make analysis-software` command remains a convenient way to run all
four analyzers locally and save reports. CI diagnostics appear in the owning
submodule job's log. Verilog analysis remains local-only and is not run by any
of these software CI scripts.

```sh
python3 -m unittest discover -s tests/static_analysis -v
```

The C fixes and CI integrations live in Git submodules. Commit and publish each
submodule change, then update the parent repository's pointers; root CI checks
out committed submodule revisions, not local uncommitted edits.

## Reviewed analyzer false positives

No Clang checker category is disabled. The compiler's `analysis.h` provides
analyzer-only annotations: fatal helpers are non-returning, and parser helpers
assume the non-NULL cursors established by `parse_prog`. The assembler models
the positive label-list capacity established by its constructor. Each use is
commented at the affected declaration or function. These annotations are erased
for normal GCC and self-hosted builds, avoiding a Clang dependency in Dioptase C.

This follows Clang's guidance to
[model invariants and non-returning helpers](https://clang.llvm.org/docs/analyzer/user-docs/FAQ.html)
rather than disable memory-safety checks. Update these models if the underlying
contracts change. C diagnostics have no error-count limit, so a file with many
findings still receives a complete diagnostic report.

## Working with findings

Prioritize memory safety and suspicious arithmetic/widths before style cleanup.
Confirm each suspected bug against the relevant ISA, ABI, or device contract;
the ISA file in this checkout is `docs/ISA.md`. Add a regression case for a
confirmed bug. For a false positive, document the invariant or use a narrowly
justified suppression rather than disabling an entire category of checks.
