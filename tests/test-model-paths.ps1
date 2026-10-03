$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$repo = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repo 'src\ComfyUIWorkbench.Core.psm1') -Force
$testRoot = Join-Path $repo ('data\tests\model-paths-' + [Guid]::NewGuid().ToString('N'))
$paths = Get-CuwPaths -RepositoryRoot $repo -DataRoot $testRoot
Initialize-CuwLayout -Paths $paths
if (@(Get-CuwExternalModelPaths -Paths $paths).Count -ne 0) { throw 'Default must be empty' }
if ($null -ne (Update-CuwExtraModelPaths -Paths $paths)) { throw 'Default must not add a startup argument' }
$external = Join-Path $testRoot 'shared models #1'
$null = New-Item -ItemType Directory -Path $external
$entries = @(Get-CuwModelPathTypes | ForEach-Object { [pscustomobject]@{ type=$_.Key; path=$external } })
$entries += $entries[0]
Save-CuwExternalModelPaths -Paths $paths -Entries $entries
if (@(Get-CuwExternalModelPaths -Paths $paths).Count -ne 6) { throw 'Deduplication failed' }
$yaml = Update-CuwExtraModelPaths -Paths $paths
$mapped = Get-Content -LiteralPath $yaml -Raw -Encoding UTF8 | ConvertFrom-Json
if ($mapped.workbench_external_0.base_path -ne $external -or $mapped.workbench_external_0.checkpoints -ne '.') { throw 'Escaped model mapping failed' }
foreach ($bad in @([pscustomobject]@{type='checkpoints';path='relative'},[pscustomobject]@{type='custom_nodes';path=$external},[pscustomobject]@{type='vae';path=(Join-Path $testRoot 'missing')})) {
    $rejected = $false
    try { Save-CuwExternalModelPaths -Paths $paths -Entries @($bad) } catch { $rejected = $true }
    if (-not $rejected) { throw 'Invalid model path was accepted' }
}
if (@(Get-CuwExternalModelPaths -Paths $paths).Count -ne 6) { throw 'Failed save damaged prior settings' }
$second = Join-Path $testRoot 'second source'
$null = New-Item -ItemType Directory -Path $second
$entries += [pscustomobject]@{ type='checkpoints'; path=$second }
Save-CuwExternalModelPaths -Paths $paths -Entries $entries
if (@(Get-CuwExternalModelPaths -Paths $paths).Count -ne 7) { throw 'Multiple directories per type failed' }
# Exercise the real startup argument builder with a fake process: no service is interrupted.
$module = Get-Module ComfyUIWorkbench.Core
& $module {
    function script:Get-CuwRuntimeInfo { param($Paths) return [pscustomobject]@{MainPath='D:\mock\main.py';PythonPath='D:\mock\python.exe';ComfyRoot='D:\mock'} }
    function script:Test-CuwOwnedProcess { param($Paths,$State) return $false }
    function script:Test-CuwPortAvailable { param($Port) return $true }
    function script:Test-CuwHealth { param($Port) return $true }
    function script:Test-CuwCompute { param($Paths) }
    function script:Start-Process {
        param($FilePath,$ArgumentList,$WorkingDirectory,$WindowStyle,$RedirectStandardOutput,$RedirectStandardError,[switch]$PassThru)
        $script:capturedModelArguments = $ArgumentList
        return [pscustomobject]@{ Id=12345; HasExited=$false }
    }
}
Invoke-CuwStart -Paths $paths -Port 18188 | Out-Null
$arguments = & $module { $script:capturedModelArguments }
if ($arguments -notmatch '--extra-model-paths-config' -or $arguments -notmatch 'extra-model-paths.yaml') { throw 'Startup missed external config' }
Save-CuwExternalModelPaths -Paths $paths -Entries @()
if ($null -ne (Update-CuwExtraModelPaths -Paths $paths)) { throw 'Removing all references must disable extra config' }
Invoke-CuwStart -Paths $paths -Port 18188 | Out-Null
$arguments = & $module { $script:capturedModelArguments }
if ($arguments -match '--extra-model-paths-config') { throw 'Startup retained stale external references' }
if ($arguments -match '--cpu') { throw 'GPU silently downgraded to CPU' }
$paths.Hardware = Get-CuwHardwareProfiles $repo | Where-Object { $_.id -eq 'cpu' }
Invoke-CuwStart -Paths $paths -Port 18188 | Out-Null
$arguments = & $module { $script:capturedModelArguments }
if ($arguments -notmatch '--cpu') { throw 'CPU selection did not change launch arguments' }
if (-not (Test-Path -LiteralPath $external)) { throw 'External folder was deleted' }
[xml]$markup = Get-Content (Join-Path $repo 'launcher\ModelPaths.xaml') -Raw -Encoding UTF8
$dialog = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader($markup)))
foreach ($name in @('TypeSelector','TypeDescription','DefaultPathText','ExternalPathsList','AddPathButton','RemovePathButton','SavePathsButton','CancelPathsButton')) {
    if ($null -eq $dialog.FindName($name)) { throw "Missing dialog control: $name" }
}
$dialog.Close()
Write-Output "PASS: defaults, six types, multiple paths, deduplication, escaping, invalid paths, atomic preservation, startup arguments, removal without deletion, dialog bindings. YAML: $yaml"
