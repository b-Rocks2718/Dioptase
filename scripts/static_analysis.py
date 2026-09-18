#!/usr/bin/env python3
"""Run host-side analysis without changing the normal build or test settings."""

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess


ROOT = Path(__file__).resolve().parents[1]
COMPILER_WARNING = re.compile(r"^.*:\d+:\d+: warning:", re.MULTILINE)


def run_job(name, directory, commands, report_dir):
    """Keep all diagnostics and continue after failures to cover every source."""
    log_path = report_dir / (name + ".log")
    failed = False
    with log_path.open("w", encoding="utf-8") as log:
        for command in commands:
            log.write("$ " + shlex.join(command) + "\n")
            log.flush()
            try:
                result = subprocess.run(
                    command, cwd=directory, stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT, text=True, errors="replace",
                    check=False,
                )
            except OSError as error:
                log.write(f"Cannot run {command[0]} for {name}: {error}\n"
                          "Install the tool or set its executable override; "
                          "see docs/static-analysis.md.\n")
                failed = True
                break
            log.write(result.stdout)
            log.write(f"Exit status: {result.returncode}\n\n")
            # Clang's ordinary frontend warnings need not change its exit code.
            # Report these too, without -Werror stopping analysis of that file.
            failed |= result.returncode != 0 or bool(
                COMPILER_WARNING.search(result.stdout)
            )
    status = "attention" if failed else "clean"
    print(f"{name}: {status} ({log_path})", flush=True)
    return {"name": name, "status": status, "log": str(log_path)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("component", choices=("all", "software", "c", "rust", "rtl"),
                        nargs="?", default="all")
    parser.add_argument("--output", type=Path, default=ROOT / "build/static-analysis")
    args = parser.parse_args()
    report_dir = args.output.resolve()
    report_dir.mkdir(parents=True, exist_ok=True)
    jobs = []

    if args.component in ("all", "software", "c"):
        for name, relative in (
            ("assembler", "Dioptase-Assembler"),
            ("compiler", "Dioptase-Languages/Dioptase-C-Compiler"),
        ):
            directory = ROOT / relative
            # These match the native Makefiles' src/*.c translation units and
            # default language mode. No guest ABI or kernel headers are assumed.
            commands = [
                [os.environ.get("CLANG", "clang"), "--analyze", "-Wall", "-Wextra", "-ferror-limit=0",
                 "--analyzer-output", "text", "-Xanalyzer", "-analyzer-werror",
                 str(source)]
                for source in sorted((directory / "src").glob("*.c"))
            ]
            if not commands:
                parser.error(f"No C sources in {directory / 'src'}; initialize submodules")
            jobs.append((name, directory, commands))

    if args.component in ("all", "software", "rust"):
        for variant in ("Simple", "Full"):
            directory = ROOT / "Dioptase-Emulators" / f"Dioptase-Emulator-{variant}"
            jobs.append((f"emulator-{variant.lower()}", directory, [[
                os.environ.get("CARGO", "cargo"), "clippy", "--locked",
                # Gate bug-oriented default lints, not stylistic rewrites.
                # Correctness, suspicious and performance groups stay enabled.
                "--all-targets", "--", "-D", "warnings",
                "-A", "clippy::style", "-A", "clippy::complexity",
            ]]))

    if args.component in ("all", "rtl"):
        for variant in ("Simple", "Full"):
            directory = ROOT / "Dioptase-CPUs" / f"Dioptase-Pipe-{variant}"
            sources = [str(source) for source in sorted((directory / "src").glob("*.v"))]
            if not sources:
                parser.error(f"No Verilog sources in {directory / 'src'}; initialize submodules")
            base = [os.environ.get("VERILATOR", "verilator"), "--lint-only",
                    "--Wall", "--timing", "--top-module", "dioptase",
                    "--error-limit", "0"]
            # Analyze the same top as simulation, including timed testbench code.
            # Full has different memory/device paths in its test and OS builds.
            variants = [("", [])] if variant == "Simple" else [
                ("-test", ["+define+VERILATOR_TEST"]), ("-os", []),
            ]
            for suffix, defines in variants:
                jobs.append((f"rtl-{variant.lower()}{suffix}", directory,
                             [base + defines + sources]))

    results = [run_job(name, directory, commands, report_dir)
               for name, directory, commands in jobs]
    # Each invocation replaces the summary for its selected components. Logs for
    # other components can remain; only this summary describes the current run.
    (report_dir / "summary.json").write_text(
        json.dumps(results, indent=2) + "\n", encoding="utf-8"
    )
    return int(any(result["status"] != "clean" for result in results))


if __name__ == "__main__":
    raise SystemExit(main())
