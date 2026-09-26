[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('setup','start','stop','status','doctor','open-ui','open-models','open-workflows','open-output')][string]$Command = 'status',
    [string]$DataRoot,
    [ValidateRange(1024,65535)][int]$Port = 8188
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repositoryRoot 'src\ComfyUIWorkbench.Core.psm1') -Force
if ([string]::IsNullOrWhiteSpace($DataRoot)) { $DataRoot = Join-Path $repositoryRoot 'data' }
$paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $DataRoot

try {
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
