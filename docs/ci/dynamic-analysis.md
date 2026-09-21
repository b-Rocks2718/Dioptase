# Dynamic memory analysis

Valgrind Memcheck runs over the native C programs whose behavior can be
observed correctly on the host:

```sh
make valgrind             # Assembler and compiler; continues after one fails
make valgrind-c           # Alias for all native C tools
make valgrind-assembler   # Assembler debug suite
make valgrind-compiler    # Compiler debug suite and native C test harnesses
```

The component scripts are also directly runnable from a standalone checkout:

```sh
bash .github/scripts/valgrind.sh
```

## Policy and coverage

Memcheck reports invalid reads/writes, use of uninitialized values, and double
or invalid frees as failures across every selected invocation. Every leak kind
is also a failure across the entire assembler and compiler suites: definite,
indirect, possible, and still-reachable. Debug executables are used so reports
contain useful source locations; debug/release functional suites still run
separately in CI.

The assembler runner wraps every invocation in its normal debug suite. The
compiler runner wraps direct `bcc` tests, native TAC/compiler test harnesses,
and the `bcc` child processes launched by emulator execution tests. It does not
trace into GCC, the assembler, the Rust emulators, or compiled reference
programs; those are separate executables with their own checks.

Expected-failure inputs need special handling: both tools deliberately return
nonzero for invalid programs. The wrapper reserves a distinct Memcheck status
and records it out-of-band, so a memory error cannot be mistaken for a correct
input rejection.

These checks do not run Dioptase binaries under Valgrind. Guest programs use a
custom ISA and execute inside the emulators, so host Memcheck cannot instrument
their instructions. The Rust emulators remain covered by Clippy and their Rust
test suites. The OS and RTL are likewise outside this host-memory check.

## Requirements and configuration

Install Valgrind (tested with 3.22) and initialize the relevant submodules. The
compiler check also needs the compiler's normal build dependencies, including
Cargo and the two emulator repositories. Set `VALGRIND` to override the
executable path; it accepts one executable path, not a shell command or extra
flags.

The hosted assembler and compiler workflows install Valgrind explicitly and
their component-owned CI scripts run these checks. That keeps standalone
submodule CI and the root `software-ci.yml` workflow on the same policy.
