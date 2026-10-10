param([string]$Godot = "C:/Godot/godot.exe", [switch]$Graphics)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -GodotArgs @("--headless","--path","$repo/client","--editor","--import","--quit") -Label "online-quests-import"
Push-Location "$repo/server"
try {
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "Backend build failed" }
    $mode = if ($Graphics) { "quests-graphics" } else { "quests" }
    node dist/tests/godot-network-runner.js $Godot $mode
    if ($LASTEXITCODE -ne 0) { throw "Godot online quests failed" }
} finally { Pop-Location }
