param([string]$Godot = "C:/Godot/godot.exe")
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -GodotArgs @("--headless","--path","$repo/client","--editor","--import","--quit") -Label "network-import"
Push-Location "$repo/server"
try {
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "Backend build failed" }
    node dist/tests/godot-network-runner.js $Godot
    if ($LASTEXITCODE -ne 0) { throw "Godot network transport failed" }
} finally { Pop-Location }
