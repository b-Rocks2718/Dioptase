[CmdletBinding()]
param(
    [ValidateRange(0, 3600)]
    [int]$DelaySeconds = 120,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($DelaySeconds -gt 0) {
    Write-Host "Delaying Windows suspend for $DelaySeconds seconds so GitHub Actions can flush logs."
    Start-Sleep -Seconds $DelaySeconds
}

if ($DryRun) {
    Write-Host "Dry run requested; Windows suspend was not attempted."
    exit 0
}

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
