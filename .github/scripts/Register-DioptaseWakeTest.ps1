[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateNotNullOrEmpty()]
    [string]$TaskName = "Dioptase Wake Test",

    [ValidateRange(1, 1440)]
    [int]$MinutesFromNow = 3,

    [ValidateNotNullOrEmpty()]
    [string]$WslDistro = "Ubuntu",

    [string]$WslUser = "root",

    [ValidateNotNullOrEmpty()]
    [string]$WslCommand = "systemctl restart actions.runner.b-Rocks2718-Dioptase.brooks-desktop.service",

    [ValidateRange(0, 7200)]
    [int]$AwakeSeconds = 1200,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ($WslDistro.Contains('"')) {
    throw 'WslDistro must not contain double quotes.'
}

if ($WslUser.Contains('"')) {
    throw 'WslUser must not contain double quotes.'
}

if ($WslCommand.Contains('"')) {
    throw 'WslCommand must not contain double quotes. Put complex runner startup logic in a WSL-side script and call that script here.'
}

$wakeAt = (Get-Date).AddMinutes($MinutesFromNow)
$wslDistroLiteral = $WslDistro.Replace("'", "''")
$wslUserLiteral = $WslUser.Replace("'", "''")
$wslCommandLiteral = $WslCommand.Replace("'", "''")

$wakeScript = @"
`$ErrorActionPreference = "Continue"

`$signature = @'
using System;
using System.Runtime.InteropServices;

public static class DioptaseExecutionState
{
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
'@

Add-Type -TypeDefinition `$signature -ErrorAction Stop

`$esContinuous = [Convert]::ToUInt32("80000000", 16)
`$esKeepAwake = [Convert]::ToUInt32("80000001", 16)
[DioptaseExecutionState]::SetThreadExecutionState(`$esKeepAwake) | Out-Null

try {
    `$wslDistro = '$wslDistroLiteral'
    `$wslUser = '$wslUserLiteral'
    if (-not [string]::IsNullOrWhiteSpace(`$wslDistro)) {
        `$wslArgs = @("-d", `$wslDistro)
        if (-not [string]::IsNullOrWhiteSpace(`$wslUser)) {
            `$wslArgs += @("-u", `$wslUser)
        }
        `$wslArgs += @("-e", "/bin/sh", "-lc", '$wslCommandLiteral')
        & "`$env:WINDIR\System32\wsl.exe" @wslArgs
    }

    Start-Sleep -Seconds $AwakeSeconds
} finally {
    [DioptaseExecutionState]::SetThreadExecutionState(`$esContinuous) | Out-Null
}
"@

$encodedWakeScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wakeScript))

$action = New-ScheduledTaskAction `
    -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedWakeScript"

$trigger = New-ScheduledTaskTrigger -Once -At $wakeAt

$settings = New-ScheduledTaskSettingsSet `
    -WakeToRun `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

$description = "One-time Dioptase wake test. Wakes Windows, starts WSL, and holds the host awake briefly so GitHub Actions can assign queued work."
$task = New-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description $description

if ($PSCmdlet.ShouldProcess($TaskName, "register one-time wake test task")) {
    Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force:$Force | Out-Null

    Write-Host "Registered '$TaskName' to wake Windows at: $($wakeAt.ToString('yyyy-MM-dd HH:mm:ss'))."
    Write-Host "The task will start WSL distro '$WslDistro' as user '$WslUser' with command: $WslCommand"
    Write-Host "The task will request that Windows stay awake for $AwakeSeconds seconds after wake."
    Write-Host "Verify pending wake timers with: powercfg /waketimers"
    Write-Host "Clean up this one-time task with: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
}
