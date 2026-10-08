$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $repo "server")
try {
    $testOutput = npm test
    $testExit = $LASTEXITCODE
    New-Item -ItemType Directory -Force (Join-Path $repo "artifacts") | Out-Null
    $testOutput | Set-Content (Join-Path $repo "artifacts/backend-test.log") -Encoding UTF8
    Write-Output $testOutput
    if ($testExit -ne 0) { throw "Backend tests failed" }
    node dist/src/main.js --smoke-server
    if ($LASTEXITCODE -ne 0) { throw "Server entrypoint smoke failed" }
} finally { Pop-Location }
