param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$client = Join-Path $repo "client"
node "$PSScriptRoot/sync-data.mjs"
if ($LASTEXITCODE -ne 0) { throw "Shared data sync failed" }
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label import -GodotArgs @("--headless", "--path", $client, "--editor", "--import", "--quit")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label smoke -Expected "PASS foundation" -GodotArgs @("--headless", "--path", $client, "--", "--smoke")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label movement -Expected "PASS movement" -GodotArgs @("--headless", "--path", $client, "res://scenes/test_movement.tscn")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label characters -Expected "PASS characters" -GodotArgs @("--headless", "--path", $client, "res://scenes/test_characters.tscn")
