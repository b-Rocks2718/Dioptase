# Dioptase Self-Hosted Actions Runner

This setup runs the Dioptase assembler, full emulator, compiler, and OS test
suites twice a day on this Windows machine while still allowing the machine to
sleep when it is idle.

This is host and CI infrastructure only. It does not define or change any
Dioptase architectural behavior.

## Design

- GitHub Actions owns the test job and records the result.
- Windows Task Scheduler wakes the machine before the GitHub Actions schedule.
- A Linux self-hosted runner, normally inside WSL, runs the toolchain and OS tests.
- A final workflow job suspends the Windows host after all scheduled test jobs finish.
- The workflow has no `pull_request` trigger because self-hosted runners should
  not execute untrusted fork code.

GitHub cannot wake a sleeping self-hosted runner by itself. The runner must be
awake and connected before the scheduled job can be picked up.

## Schedule

The workflow is in `.github/workflows/dioptase-os-tests.yml`.

It runs at 10:05 and 22:05 in `America/Chicago` time:

```yaml
schedule:
  - cron: "5 10,22 * * *"
    timezone: America/Chicago
```

The Windows wake task defaults to 09:55 and 21:55, which gives the host about
10 minutes to wake, reconnect networking, and bring the runner online. After
wake, the task also asks Windows to stay awake for 20 minutes so the host does
not go back to sleep before GitHub assigns the queued job.

## Test Coverage

The workflow's `toolchain-tests` job cleans and rebuilds release artifacts, then
runs only release-mode tests for the assembler, full emulator, and compiler:

```sh
make -C Dioptase-Assembler clean
make -C Dioptase-Assembler release
make -C Dioptase-Assembler test-release
cargo clean --release --manifest-path Dioptase-Emulators/Dioptase-Emulator-Full/Cargo.toml
cargo build --release --manifest-path Dioptase-Emulators/Dioptase-Emulator-Full/Cargo.toml
cargo test --release --manifest-path Dioptase-Emulators/Dioptase-Emulator-Full/Cargo.toml
make -C Dioptase-Languages/Dioptase-C-Compiler clean
make -C Dioptase-Languages/Dioptase-C-Compiler release
DIOPTASE_ROOT="$PWD" make -C Dioptase-Languages/Dioptase-C-Compiler test-release
```

The `os-tests` job also rebuilds the release assembler, full emulator, and
compiler before cleaning and running the OS release tests:

```sh
make -C Dioptase-OS clean
make -C Dioptase-OS -j16 --output-sync=target test VERSION=release TEST_RUNS="$DIOPTASE_OS_TEST_RUNS"
```

The `-j16` option lets GNU Make run up to 16 independent OS summary-test
targets at once. `--output-sync=target` keeps each test target's output grouped
so parallel logs remain readable.

The compiler's optional WACC targets are not included because this checkout does
not currently include `tests/writing-a-c-compiler-tests/test_compiler`.

## Runner Setup

Install the GitHub Actions runner in WSL as a Linux x64 self-hosted runner and
give it the custom label `dioptase-os`. The workflow targets:

```yaml
runs-on: [self-hosted, linux, x64, dioptase-os]
```

Minimum WSL-side tools expected by the workflow:

```sh
sudo apt install build-essential e2fsprogs python3 make gcc
```

The OS harness also needs Rust/Cargo for `Dioptase-Emulators/Dioptase-Emulator-Full`.
Install Rust using the project-standard method for this machine.

After configuring the runner in WSL, install it as a service from the runner
directory so it comes back after WSL starts:

```sh
sudo ./svc.sh install "$USER"
sudo ./svc.sh start
```

## Windows Wake Task

From WSL, register the Windows wake task with:

```sh
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w .github/scripts/Register-DioptaseWakeTask.ps1)" -WslDistro Ubuntu -Force
```

Replace `Ubuntu` with the actual WSL distro name from:

```sh
wsl.exe -l -v
```

The default task wakes the host, restarts the GitHub runner systemd service as
WSL `root`, and asks Windows to stay awake for 20 minutes. Restarting the runner
service clears stale GitHub sessions after sleep:

```sh
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w .github/scripts/Register-DioptaseWakeTask.ps1)" -WslDistro Ubuntu -Force
```

If your runner service name changes, pass the new command with `-WslCommand`.
Keep complex startup logic in a WSL-side script so Task Scheduler quoting stays
simple. Pass `-WslUser` if the command should run as a WSL user other than
`root`.

To change the post-wake keep-awake window, pass `-AwakeSeconds`:

```sh
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w .github/scripts/Register-DioptaseWakeTask.ps1)" -WslDistro Ubuntu -AwakeSeconds 1800 -Force
```

For a one-time wake test three minutes from now, use:

```sh
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w .github/scripts/Register-DioptaseWakeTest.ps1)" -Force
```

Check the registered wake timers from Windows PowerShell or WSL:

```sh
powercfg.exe /waketimers
```

## Sleep Behavior

Scheduled runs suspend Windows after the toolchain and OS jobs both finish.
Manual `workflow_dispatch` runs do not sleep the host unless `sleep_after` is
set to `true`.

To temporarily disable automatic sleep for scheduled runs without editing the
workflow, set the repository variable `DIOPTASE_SLEEP_AFTER_TESTS` to `false`.

The suspend helper schedules a detached PowerShell process that waits 120 seconds
before calling the Windows power API. The helper returns immediately so GitHub
Actions can record the sleep job as complete before the host suspends:

```sh
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w .github/scripts/Suspend-Windows.ps1)" -DryRun
```

For manual debugging, pass `-Synchronous` to use the old blocking behavior:

```sh
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w .github/scripts/Suspend-Windows.ps1)" -DelaySeconds 5 -Synchronous
```

If that command fails with `Exec format error`, WSL interop is disabled or
blocked in the current shell. The workflow will detect that state and leave the
host awake instead of failing the test job's final sleep step.

## CI Failure Semantics

`Dioptase-OS/Makefile` currently prints failing summaries such as
`[heap_test] fail: ...` without making the aggregate `make test` command return
a non-zero status. The workflow therefore scans the aggregate log and fails the
job if any summary line starts with `[name] fail:`.

`Dioptase-Assembler` and `Dioptase-Languages/Dioptase-C-Compiler` also print
`Summary: passed / total tests passed` lines, so the workflow fails those jobs
when `passed != total` even if `make` exits 0.

The summary-scanning wrappers should be removed if those Makefile aggregate
targets are later changed to return non-zero on any failing baseline.

## References

- GitHub Actions workflow schedule syntax: https://docs.github.com/actions/using-workflows/events-that-trigger-workflows#schedule
- GitHub self-hosted runner labels: https://docs.github.com/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners
- GitHub self-hosted runner service setup: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/configuring-the-self-hosted-runner-application-as-a-service?platform=linux
- Windows scheduled task wake setting: https://learn.microsoft.com/powershell/module/scheduledtasks/new-scheduledtasksettingsset
- Windows `powercfg /waketimers`: https://learn.microsoft.com/windows-hardware/design/device-experiences/powercfg-command-line-options
- Windows `SetSuspendState`: https://learn.microsoft.com/windows/win32/api/powrprof/nf-powrprof-setsuspendstate
