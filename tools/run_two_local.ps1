# Launches two local instances: one hosts (west cliff), one joins (east cliff).
# Usage: powershell -File tools\run_two_local.ps1 [-Godot path\to\godot.exe] [-Extra "--fast --debug"]
param(
    [string]$Godot = "",
    [string]$Extra = "--fast --debug",
    [string]$HostExtra = "",
    [string]$JoinExtra = "",
    [string]$LogDir = "",
    [switch]$Wait
)
$root = Split-Path -Parent $PSScriptRoot
if ($Godot -eq "") {
    $found = Get-ChildItem -Path $root -Filter "Godot_*_console.exe" | Select-Object -First 1
    if ($null -eq $found) { $found = Get-ChildItem -Path $root -Filter "Godot_*.exe" | Select-Object -First 1 }
    if ($null -eq $found) { Write-Error "Godot not found; pass -Godot"; exit 1 }
    $Godot = $found.FullName
}
if ($LogDir -eq "") { $LogDir = Join-Path $env:TEMP "dust_and_mandibles" }
New-Item -ItemType Directory -Force $LogDir | Out-Null

$hostArgs = "--path `"$root`" --position 0,40 --resolution 1280x720 -- --host --name=Host $Extra $HostExtra"
$joinArgs = "--path `"$root`" --position 1300,40 --resolution 1280x720 -- --join --name=Partner $Extra $JoinExtra"
$h = Start-Process -FilePath $Godot -ArgumentList $hostArgs -PassThru `
    -RedirectStandardOutput "$LogDir\host.log" -RedirectStandardError "$LogDir\host.err"
Start-Sleep -Seconds 3
$j = Start-Process -FilePath $Godot -ArgumentList $joinArgs -PassThru `
    -RedirectStandardOutput "$LogDir\join.log" -RedirectStandardError "$LogDir\join.err"
Write-Output "Host PID $($h.Id), join PID $($j.Id). Logs in $LogDir"
if ($Wait) {
    $h.WaitForExit(); $j.WaitForExit()
}
