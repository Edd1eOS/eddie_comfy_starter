$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repo 'src/ComfyUIWorkbench.Core.psm1') -Force
$root = Join-Path $repo ('data/tests/probe-' + [guid]::NewGuid().ToString('N'))
$paths = Get-CuwPaths $repo $root
$paths.Hardware = @(Get-CuwHardwareProfiles $repo | Where-Object id -eq 'intel')[0]
$before = [Environment]::GetEnvironmentVariable('SYCL_CACHE_DIR', 'Process')
& (Get-Module ComfyUIWorkbench.Core) {
    param($paths)
    function script:Get-CuwRuntimeInfo { param($Paths) return @{PythonPath='mock-python'} }
    $script:ProbeMode = 'success'
    function script:Start-Process {
        param($FilePath,$ArgumentList,$WindowStyle,$RedirectStandardOutput,$RedirectStandardError,[switch]$PassThru)
        if ($env:SYCL_CACHE_PERSISTENT -ne '1' -or $env:SYCL_CACHE_DIR -ne (Join-Path $paths.DataRoot 'cache/intel-sycl')) { throw 'Missing child cache environment' }
        if ($script:ProbeMode -eq 'launchFailure') { throw 'Simulated process creation failure' }
        $command = switch ($script:ProbeMode) { success {'exit 0'} failure {'exit 9'} timeout {'Start-Sleep -Seconds 20'} }
        $script:ProbeChild = Microsoft.PowerShell.Management\Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-Command', ('"'+$command+'"')) -WindowStyle Hidden -RedirectStandardOutput $RedirectStandardOutput -RedirectStandardError $RedirectStandardError -PassThru
        return $script:ProbeChild
    }
    Test-CuwCompute $paths -TimeoutSeconds 10
    foreach ($mode in @('failure','timeout','launchFailure')) {
        $script:ProbeMode = $mode
        $caught = $false
        try { Test-CuwCompute $paths -TimeoutSeconds 1 } catch { $caught = $true }
        if (-not $caught) { throw "Probe $mode was reported successful" }
        $record = Read-CuwJson (Join-Path $paths.VersionRoot 'compute-xpu.json')
        if ($record.success) { throw 'Failure record was not persisted' }
        if ($mode -ne 'launchFailure' -and -not $script:ProbeChild.HasExited) { throw 'Timed out child still running' }
    }
} $paths
if ([Environment]::GetEnvironmentVariable('SYCL_CACHE_DIR','Process') -ne $before) { throw 'Process environment was not restored' }
Write-Output 'PASS: exit code, failure record, bounded timeout, owned-child termination, Intel cache isolation.'
