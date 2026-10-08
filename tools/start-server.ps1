param([switch]$Install, [switch]$Smoke)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $repo "server")
try {
    $env:NODE_USE_SYSTEM_CA = "1"
    if ($Install -or -not (Test-Path node_modules)) {
        npm ci
        if ($LASTEXITCODE -ne 0) { throw "Local dependency installation failed" }
    }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "Server build failed" }
    if ($Smoke) { npm start -- --smoke-server } else { npm start }
    if ($LASTEXITCODE -ne 0) { throw "Server stopped with error" }
} finally { Pop-Location }
