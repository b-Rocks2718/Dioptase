[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateNotNullOrEmpty()]
    [string]$TaskName = "Dioptase OS Tests Wake",

    [ValidateNotNullOrEmpty()]
    [string[]]$Times = @("09:55", "21:55"),

    [string]$WslDistro = "",

    [ValidateNotNullOrEmpty()]
    [string]$WslCommand = "true",

    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ($WslDistro.Contains('"')) {
    throw 'WslDistro must not contain double quotes.'
}

if ($WslCommand.Contains('"')) {
    throw 'WslCommand must not contain double quotes. Put complex runner startup logic in a WSL-side script and call that script here.'
}

$timeFormats = [string[]]@("H:mm", "HH:mm", "h:mm tt", "hh:mm tt")
$triggers = foreach ($time in $Times) {
    try {
        $parsed = [datetime]::ParseExact(
            $time,
            $timeFormats,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None)
    } catch {
        throw "Invalid wake time '$time'. Expected HH:mm, for example 06:05 or 18:05."
    }

    New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.Add($parsed.TimeOfDay))
}

if ([string]::IsNullOrWhiteSpace($WslDistro)) {
    $action = New-ScheduledTaskAction `
        -Execute "$env:WINDIR\System32\cmd.exe" `
        -Argument "/c exit /b 0"
} else {
    $action = New-ScheduledTaskAction `
        -Execute "$env:WINDIR\System32\wsl.exe" `
        -Argument "-d `"$WslDistro`" -e /bin/sh -lc `"$WslCommand`""
}

$settings = New-ScheduledTaskSettingsSet `
    -WakeToRun `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

$description = "Wake Windows before the scheduled Dioptase OS GitHub Actions self-hosted runner job. The task does not run the OS tests."
$task = New-ScheduledTask `
    -Action $action `
    -Trigger $triggers `
    -Settings $settings `
    -Description $description

if ($PSCmdlet.ShouldProcess($TaskName, "register scheduled wake task")) {
    Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force:$Force | Out-Null

    $joinedTimes = $Times -join ", "
    Write-Host "Registered '$TaskName' to wake Windows daily at: $joinedTimes."
    if ([string]::IsNullOrWhiteSpace($WslDistro)) {
        Write-Host "No WSL distro was configured; the task only wakes Windows."
    } else {
        Write-Host "The task will start WSL distro '$WslDistro' with command: $WslCommand"
    }
    Write-Host "Verify pending wake timers with: powercfg /waketimers"
}
