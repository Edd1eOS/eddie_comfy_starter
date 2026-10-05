param([ValidateSet('cpu','intel','nvidia')][string]$Hardware='cpu',[switch]$Train,[switch]$TrainingOnly,[switch]$FullPrecision,[switch]$SplitAttention,[int]$TimeoutSeconds=900)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repo 'src/ComfyUIWorkbench.Core.psm1') -Force
$root=Join-Path $repo ('data/hardware-validation/'+$Hardware)
$paths=Get-CuwPaths $repo $root
Set-CuwHardwareProfile $paths $Hardware
$paths=Get-CuwPaths $repo $root
if($Hardware -in @('cpu','nvidia')) {
    # CPU profile intentionally reuses the official CUDA bundle, with --cpu.
    $paths.VersionRoot=Join-Path $repo 'data/runtime/versions/comfyui-v0.37.0-nvidia'
}
if($null -eq (Get-CuwRuntimeInfo $paths)){throw 'Prepare this isolated runtime before running the test.'}
Initialize-CuwLayout $paths
Save-CuwExternalModelPaths $paths @([pscustomobject]@{type='checkpoints';path=(Join-Path $repo 'data/userdata/models/checkpoints')})
$port=switch($Hardware){cpu{18288}intel{18289}nvidia{18290}}
$runtime=Get-CuwRuntimeInfo $paths
if($FullPrecision -or $SplitAttention) {
    # Diagnostic-only override, not a change to shipped launcher defaults.
    & (Get-Module ComfyUIWorkbench.Core) {
        param($fullPrecision, $splitAttention)
        $script:DiagnosticFlags = ''
        if ($fullPrecision) { $script:DiagnosticFlags += ' --force-fp32 --fp32-text-enc --lowvram --disable-dynamic-vram' }
        if ($splitAttention) { $script:DiagnosticFlags += ' --use-split-cross-attention' }
        function script:Start-Process {
            param($FilePath,$ArgumentList,$WorkingDirectory,$WindowStyle,$RedirectStandardOutput,$RedirectStandardError,[switch]$PassThru)
            $parameters = @{} + $PSBoundParameters
            if ($ArgumentList -match 'main\.py') { $parameters.ArgumentList = $ArgumentList + $script:DiagnosticFlags }
            Microsoft.PowerShell.Management\Start-Process @parameters
        }
    } $FullPrecision $SplitAttention
}
try {
    Invoke-CuwSetup $paths
    Invoke-CuwStart $paths -Port $port
    $stats=Invoke-RestMethod "http://127.0.0.1:$port/system_stats"
    $expected=switch($Hardware){cpu{'cpu'}intel{'xpu'}nvidia{'cuda'}}
    if($stats.devices[0].type -ne $expected){throw 'Wrong backend; do not silently fall back.'}
    $stats.devices | ConvertTo-Json -Compress | Write-Output
    Invoke-CuwDoctor $paths -Port $port
    $size=if($Hardware -eq 'cpu'){256}else{512}
    $steps=if($Hardware -eq 'cpu'){4}else{12}
    if(-not $TrainingOnly) {
        & $runtime.PythonPath (Join-Path $PSScriptRoot 'smoke-generation-api.py') --port $port --size $size --steps $steps --timeout $TimeoutSeconds
        if($LASTEXITCODE -ne 0){throw 'Generation smoke failed.'}
    }
    if($Train -or $TrainingOnly) {
        & $runtime.PythonPath (Join-Path $PSScriptRoot 'smoke-training-api.py') --port $port --timeout $TimeoutSeconds
        if($LASTEXITCODE -ne 0){throw 'Native training smoke failed.'}
    }
} finally {Invoke-CuwStop $paths}
