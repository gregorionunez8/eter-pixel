param([string]$Godot = "godot", [string[]]$GodotArgs, [string]$Label = "godot", [int]$TimeoutSeconds = 45, [string]$Expected = "")
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $repo "artifacts"
New-Item -ItemType Directory -Force $logs | Out-Null
$exe = (Get-Command $Godot -ErrorAction Stop).Source
$stdout = Join-Path $logs "$Label.stdout.log"
$stderr = Join-Path $logs "$Label.stderr.log"
$quotedArgs = $GodotArgs | ForEach-Object { '"' + $_ + '"' }
$process = Start-Process -FilePath $exe -ArgumentList $quotedArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$process.Handle | Out-Null
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id
    throw "$Label timed out after $TimeoutSeconds seconds"
}
$output = (Get-Content $stdout -Raw) + (Get-Content $stderr -Raw)
Write-Output $output
if ($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR|Parse Error|ERROR:|Assertion failed') { throw "$Label failed (exit $($process.ExitCode))" }
if ($Expected -and $output -notmatch [regex]::Escape($Expected)) { throw "$Label missing required result: $Expected" }
