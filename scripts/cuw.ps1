[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('setup','start','stop','status','doctor','models','download-model','open-ui','open-models','open-workflows','open-output')][string]$Command = 'status',
    [string]$DataRoot,
    [ValidateRange(1024,65535)][int]$Port = 8188,
    [string]$ModelId,
    [ValidateSet('nvidia','nvidia-legacy','amd','intel','cpu')][string]$Hardware,
    [switch]$AcceptLicense
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repositoryRoot 'src\ComfyUIWorkbench.Core.psm1') -Force
if ([string]::IsNullOrWhiteSpace($DataRoot)) { $DataRoot = Join-Path $repositoryRoot 'data' }
$paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $DataRoot

try {
    if ($Hardware) {
        if ($Command -ne 'setup') { throw '-Hardware 仅用于 setup；其他操作沿用已保存的选择。' }
        Set-CuwHardwareProfile -Paths $paths -ProfileId $Hardware
        $paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $DataRoot
    }
    switch ($Command) {
        'setup' { Invoke-CuwSetup -Paths $paths }
        'start' { Invoke-CuwStart -Paths $paths -Port $Port }
        'stop' { Invoke-CuwStop -Paths $paths }
        'status' {
            $summary = Get-CuwSummary -Paths $paths -Port $Port
            Write-Output ("[{0}] {1}" -f $summary.Status, $summary.Message)
            Write-Output ("地址：{0}" -f $summary.Url)
            Write-Output ("存储位置：{0}" -f $summary.DataRoot)
        }
        'doctor' { Invoke-CuwDoctor -Paths $paths -Port $Port }
        'models' {
            foreach ($model in (Get-CuwModelCatalog -Paths $paths)) {
                $state = Get-CuwModelState -Paths $paths -Model $model
                Write-Output ("{0}  {1}  {2}  [{3}]" -f $model.id, $model.displayName, (Format-CuwByteSize -Bytes ([long]$model.sizeBytes)), $state.Message)
            }
        }
        'download-model' {
            if ([string]::IsNullOrWhiteSpace($ModelId)) { throw (New-CuwException -Message '请选择要下载的模型。' -ExitCode 2) }
            Invoke-CuwModelDownload -Paths $paths -ModelId $ModelId -AcceptLicense:$AcceptLicense
        }
        'open-ui' {
            $summary = Get-CuwSummary -Paths $paths -Port $Port
            if (-not $summary.Installed) { throw (New-CuwException -Message '工作台还没有准备好。请先运行 setup。' -ExitCode 3) }
            if (-not $summary.Running) { Invoke-CuwStart -Paths $paths -Port $Port }
            Start-Process $summary.Url
        }
        'open-models' { Initialize-CuwLayout -Paths $paths; Open-CuwPath -Path $paths.ModelsRoot }
        'open-workflows' { Initialize-CuwLayout -Paths $paths; Open-CuwPath -Path $paths.WorkflowsRoot }
        'open-output' { Initialize-CuwLayout -Paths $paths; Open-CuwPath -Path $paths.OutputRoot }
    }
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit (Get-CuwExitCode -Exception $_.Exception)
}
