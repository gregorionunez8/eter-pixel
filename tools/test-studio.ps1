param([string]$Godot="godot",[switch]$Graphics)
$ErrorActionPreference="Stop"
$repo=Split-Path $PSScriptRoot -Parent
$client=Join-Path $repo "client"
node "$PSScriptRoot/sync-data.mjs"
if($LASTEXITCODE -ne 0){throw "Shared data sync failed"}
& "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label studio-import -GodotArgs @("--headless","--path",$client,"--editor","--import","--quit")
foreach($suite in @("registry","ui","assets","maps","runtime")){
 [string[]]$mode=@("--headless")
 if($Graphics -and $suite -in @("ui","maps","runtime")){$mode=@()}
 & "$PSScriptRoot/invoke-godot.ps1" -Godot $Godot -Label "studio-$suite" -Expected "PASS Studio $suite" -GodotArgs ($mode+@("--path",$client,"res://scenes/test_studio_$suite.tscn"))
}
