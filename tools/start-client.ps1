param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
& $Godot --path (Join-Path (Split-Path $PSScriptRoot -Parent) "client")
