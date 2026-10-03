$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repo 'src\ComfyUIWorkbench.Core.psm1') -Force
$source = Get-Content (Join-Path $repo 'launcher\ComfyUIWorkbench.ps1') -Raw -Encoding UTF8
$settingsCode = $source.Substring($source.IndexOf('$settingsRoot ='), $source.IndexOf('$script:Port =') - $source.IndexOf('$settingsRoot ='))
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
$save = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Save-CuwLauncherSettings' }, $true)
. ([scriptblock]::Create($save.Extent.Text))
$repositoryRoot = Join-Path $repo ('data\tests\portable-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $repositoryRoot -Force
$null = New-Item -ItemType File -Path (Join-Path $repositoryRoot 'portable.mode')
. ([scriptblock]::Create($settingsCode))
if ($settingsRoot -ne (Join-Path $repositoryRoot 'data\launcher-settings')) { throw 'Portable mode leaked global settings' }
if ($script:DataRoot -ne (Join-Path $repositoryRoot 'data')) { throw 'Wrong portable default' }
Save-CuwLauncherSettings
if ((Read-CuwJson $settingsPath).dataRoot -ne 'data') { throw 'Default path must remain relocatable' }
$otherRoot = Join-Path $repositoryRoot 'moved'
$null = New-Item -ItemType Directory -Path (Join-Path $otherRoot 'data\launcher-settings') -Force
Copy-Item $settingsPath (Join-Path $otherRoot 'data\launcher-settings\settings.json')
$null = New-Item -ItemType File -Path (Join-Path $otherRoot 'portable.mode')
$repositoryRoot = $otherRoot
. ([scriptblock]::Create($settingsCode))
if ($script:DataRoot -ne (Join-Path $repositoryRoot 'data')) { throw 'Relocated settings failed' }
Write-Output 'PASS: isolated portable settings, relative default, relocated data path.'
