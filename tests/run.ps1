$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repositoryRoot 'src\ComfyUIWorkbench.Core.psm1') -Force
$script:Passed = 0
$script:Failed = 0

function Assert-CuwTest {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:Passed++; Write-Output ("[PASS] {0}" -f $Name) }
    else { $script:Failed++; Write-Output ("[FAIL] {0}" -f $Name) }
}

$testRoot = Join-Path $env:TEMP ('comfyui-workbench-tests-' + [Guid]::NewGuid().ToString('N'))
try {
    $paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $testRoot
    $expectedCheckpoints = [IO.Path]::GetFullPath((Join-Path $testRoot 'userdata\models\checkpoints'))
    Assert-CuwTest ($paths.CheckpointsRoot -eq $expectedCheckpoints) 'descriptive checkpoint directory'
    Initialize-CuwLayout -Paths $paths
    Assert-CuwTest ((Test-Path $paths.ModelsRoot) -and (Test-Path $paths.WorkflowsRoot) -and
        (Test-Path $paths.OutputRoot) -and (Test-Path $paths.CustomNodesRoot)) 'managed layout including controlled custom nodes is created'

    $jsonPath = Join-Path $paths.StateRoot 'roundtrip.json'
    Write-CuwJsonAtomic -Path $jsonPath -Value ([ordered]@{ answer = 42; name = '工作台' })
    $roundtrip = Read-CuwJson -Path $jsonPath
    Assert-CuwTest ($roundtrip.answer -eq 42 -and $roundtrip.name -eq '工作台') 'JSON writes atomically and round-trips'

    $summary = Get-CuwSummary -Paths $paths
    Assert-CuwTest (-not $summary.Installed -and $summary.Status -eq 'notReady') 'fresh data directory reports setup requirement'

    $lock = Read-CuwJson -Path (Join-Path $repositoryRoot 'configs\upstream-lock.json')
    Assert-CuwTest ($lock.comfyui.version -eq 'v0.37.0' -and ([string]$lock.comfyui.windowsNvidia.sha256).Length -eq 64) 'official portable release is version and hash locked'

    [xml](Get-Content -LiteralPath (Join-Path $repositoryRoot 'launcher\ComfyUIWorkbench.xaml') -Raw -Encoding UTF8) | Out-Null
    Assert-CuwTest $true 'launcher XAML parses as XML'

    $launcherSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'launcher\ComfyUIWorkbench.xaml') -Raw -Encoding UTF8
    Assert-CuwTest ($launcherSource -match '模型决定能生成什么' -and $launcherSource -match '保存好的一套生成步骤' -and $launcherSource -match '所有结果保存在本地') 'home cards explain concepts in plain language'

    $coreSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'src\ComfyUIWorkbench.Core.psm1') -Raw -Encoding UTF8
    Assert-CuwTest ($coreSource -match "'--listen', '127\.0\.0\.1'" -and $coreSource -match "'--disable-api-nodes'") 'service is loopback-only and online API nodes are disabled by default'
}
finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

Write-Output ("Tests: {0} passed, {1} failed" -f $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
