param([string]$Godot = "godot", [switch]$Graphics)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$client = Join-Path $repo "client"
node "$PSScriptRoot/sync-data.mjs"
if ($LASTEXITCODE -ne 0) { throw "Shared data sync failed" }
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label import -GodotArgs @("--headless", "--path", $client, "--editor", "--import", "--quit")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label smoke -Expected "PASS foundation" -GodotArgs @("--headless", "--path", $client, "--", "--smoke")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label movement -Expected "PASS movement" -GodotArgs @("--headless", "--path", $client, "res://scenes/test_movement.tscn")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label characters -Expected "PASS characters" -GodotArgs @("--headless", "--path", $client, "res://scenes/test_characters.tscn")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label combat -Expected "PASS combat" -GodotArgs @("--headless", "--path", $client, "res://scenes/test_combat.tscn")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label monsters -Expected "PASS monsters" -TimeoutSeconds 60 -GodotArgs @("--headless", "--path", $client, "res://scenes/test_monsters.tscn")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label progression -Expected "PASS progression" -GodotArgs @("--headless", "--path", $client, "res://scenes/test_progression.tscn")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label inventory -Expected "PASS inventory" -GodotArgs @("--headless", "--path", $client, "res://scenes/test_inventory.tscn")
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label economy -Expected "PASS economy" -GodotArgs @("--headless", "--path", $client, "res://scenes/test_economy.tscn")
if ($Graphics) {
    & "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label input-runtime -Expected "PASS input runtime" -GodotArgs @("--path", $client, "res://scenes/test_input.tscn")
    & "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label inventory-runtime -Expected "PASS inventory runtime" -GodotArgs @("--path", $client, "res://scenes/test_inventory_runtime.tscn")
    & "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label economy-runtime -Expected "PASS economy runtime" -GodotArgs @("--path", $client, "res://scenes/test_economy_runtime.tscn")
    & "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label ui-runtime -Expected "PASS UI runtime" -GodotArgs @("--path", $client, "res://scenes/test_ui_runtime.tscn")
    & "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label save-reload -Expected "PASS save reload" -GodotArgs @("--headless", "--path", $client, "res://scenes/test_save_reload.tscn")
}
