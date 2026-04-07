[CmdletBinding()]
param(
    [ValidateRange(0, 3600)]
    [int]$DelaySeconds = 120,

    [switch]$DryRun,

    [switch]$Synchronous
)

$ErrorActionPreference = "Stop"

if ($DryRun) {
    if ($Synchronous) {
        Write-Host "Dry run requested; Windows suspend would run synchronously after $DelaySeconds seconds."
    } else {
        Write-Host "Dry run requested; Windows suspend would be scheduled after $DelaySeconds seconds."
    }
    exit 0
}

function Invoke-DioptaseWindowsSuspend {
    $signature = @"
using System;
using System.Runtime.InteropServices;

public static class DioptaseNativePower
{
    [DllImport("powrprof.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);
}
"@

    Add-Type -TypeDefinition $signature -ErrorAction Stop

    $suspended = [DioptaseNativePower]::SetSuspendState($false, $false, $false)
    if (-not $suspended) {
        $win32Error = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Windows suspend failed: SetSuspendState(false, false, false) returned false with Win32 error $win32Error. Check runner account power permissions and Windows wake/sleep policy."
    }
}

if ($Synchronous) {
    if ($DelaySeconds -gt 0) {
        Write-Host "Delaying Windows suspend for $DelaySeconds seconds."
        Start-Sleep -Seconds $DelaySeconds
    }

    Invoke-DioptaseWindowsSuspend
    exit 0
}

$childScript = @"
`$ErrorActionPreference = "Stop"

Start-Sleep -Seconds $DelaySeconds

`$signature = @'
using System;
using System.Runtime.InteropServices;

public static class DioptaseNativePower
{
    [DllImport("powrprof.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);
}
'@

Add-Type -TypeDefinition `$signature -ErrorAction Stop

`$suspended = [DioptaseNativePower]::SetSuspendState(`$false, `$false, `$false)
if (-not `$suspended) {
    `$win32Error = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "Windows suspend failed: SetSuspendState(false, false, false) returned false with Win32 error `$win32Error. Check runner account power permissions and Windows wake/sleep policy."
}
"@

$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childScript))
$powerShellExe = Join-Path $PSHOME "powershell.exe"

# GitHub Actions runners mark job child processes with RUNNER_TRACKING_ID and may
# clean them up after the job exits. The detached suspend process must outlive the
# sleep-host job long enough to suspend Windows after the result has been reported.
[Environment]::SetEnvironmentVariable("RUNNER_TRACKING_ID", $null, "Process")

Start-Process `
    -FilePath $powerShellExe `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encodedCommand) `
    -WindowStyle Hidden | Out-Null

Write-Host "Scheduled detached Windows suspend in $DelaySeconds seconds. The GitHub Actions job can finish before the host sleeps."
