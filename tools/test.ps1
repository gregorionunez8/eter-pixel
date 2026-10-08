param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$client = Join-Path $repo "client"
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label import -GodotArgs @("--headless", "--path", $client, "--editor", "--import", "--quit")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label smoke -Expected "PASS foundation" -GodotArgs @("--headless", "--path", $client, "--", "--smoke")
