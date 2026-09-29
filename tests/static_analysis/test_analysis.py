"""Verify analysis failure propagation and the allocation cleanup bugs it found.

C regressions intercept only the affected translation unit's allocation calls.
This permits deterministic allocation failure without relying on host exhaustion
or linker-specific wrapping, and distinguishes parser temporaries from its arena.
"""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("analysis", ROOT / "scripts/static_analysis.py")
ANALYSIS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ANALYSIS)

ALLOCATIONS = r'''
#include <assert.h>
#include <stdlib.h>
#include <stdbool.h>

static size_t live_allocations;
static size_t allocation_calls;
static size_t fail_on_call;

static void* tracked_malloc(size_t size) {
  if (++allocation_calls == fail_on_call) return NULL;
  void* ptr = malloc(size);
  if (ptr != NULL) live_allocations++;
  return ptr;
}

static void tracked_free(void* ptr) {
  if (ptr != NULL) {
    assert(live_allocations > 0 && "free must match a tracked allocation");
    live_allocations--;
  }
  free(ptr);
}

#define malloc tracked_malloc
#define free tracked_free
'''

ASSEMBLER = ALLOCATIONS + r'''
#include "preprocessor.c"
#undef malloc
#undef free

int main(void) {
  // Three allocations: result table and one output buffer for each empty file.
  const size_t allocation_count = 3;
  int names[] = {0, 1};
  const char* argv[] = {"first.s", "second.s"};
  const char* files[] = {"", ""};
  for (size_t failure = 1; failure <= allocation_count; failure++) {
    allocation_calls = 0;
    fail_on_call = failure;
    char** outputs = preprocess(2, names, true, argv, files);
    assert(outputs == NULL && "preprocessing must report allocation failure");
    assert(live_allocations == 0 && "failure must free the table and prior files");
  }
  fail_on_call = 0;
  char** outputs = preprocess(2, names, true, argv, files);
  assert(outputs != NULL && "successful preprocessing must still work");
  tracked_free(outputs[0]);
  tracked_free(outputs[1]);
  tracked_free(outputs);
  assert(live_allocations == 0 && "success transfers ownership to the caller");
  return 0;
}
'''

PARSER = ALLOCATIONS + r'''
#include "parser.c"
#include "lexer.h"
#undef malloc
#undef free

int main(void) {
  // Each rejected declaration allocates dimensions before failing/backtracking.
  char* cases[] = {"int values[bad];", "int values[2][bad];", "int values[2;"};
  const size_t arena_block_size = 4096;
  for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
    arena_init(arena_block_size);
    set_source_context("array-dimensions.c", cases[i]);
    struct TokenArray* tokens = lex(cases[i]);
    assert(tokens != NULL && "regression input must reach the parser");
    struct Program* parsed = parse_prog(tokens);
    assert(parsed == NULL && "malformed array dimensions must be rejected");
    assert(live_allocations == 0 && "backtracking must release temporary dimensions");
    destroy_token_array(tokens);
    arena_destroy();
  }
  return 0;
}
'''


class AnalysisRunnerTests(unittest.TestCase):
    def test_diagnostics_and_failures_are_not_silently_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            for name, code, expected in (
                ("clean", "print('ok')", "clean"),
                ("warning", "print('test.c:1:2: warning: test diagnostic')", "attention"),
                ("failed", "raise SystemExit(7)", "attention"),
            ):
                result = ANALYSIS.run_job(name, directory, [
                    [sys.executable, "-c", code],
                    [sys.executable, "-c", "print('continuation marker')"],
                ], directory)
                self.assertEqual(result["status"], expected)
                self.assertIn("continuation marker", (directory / (name + ".log")).read_text())

    def test_missing_tool_fails_both_selected_jobs_and_writes_summary(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/static_analysis.py"),
                "rust", "--output", temp,
            ], env=dict(os.environ, CARGO=str(directory / "missing-cargo")),
                capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            summary = json.loads((directory / "summary.json").read_text())
            self.assertEqual([row["name"] for row in summary], ["emulator-simple", "emulator-full"])
            self.assertTrue(all(row["status"] == "attention" for row in summary))


class CleanupRegressionTests(unittest.TestCase):
    def compile_and_run(self, component, replaced_source, harness):
        source_dir = ROOT / component / "src"
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            source = directory / "regression.c"
            source.write_text(harness)
            executable = directory / "regression"
            sources = [str(path) for path in sorted(source_dir.glob("*.c"))
                       if path.name not in ("main.c", replaced_source)]
            result = subprocess.run([
                os.environ.get("CC", "gcc"), "-I", str(source_dir), str(source),
                *sources, "-o", str(executable),
            ], capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([str(executable)], capture_output=True,
                                    text=True, check=False, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_assembler_releases_prior_outputs_on_allocation_failure(self):
        self.compile_and_run("Dioptase-Assembler", "preprocessor.c", ASSEMBLER)

    def test_parser_releases_dimensions_when_backtracking(self):
        self.compile_and_run("Dioptase-Languages/Dioptase-C-Compiler", "parser.c", PARSER)


if __name__ == "__main__":
    unittest.main()
