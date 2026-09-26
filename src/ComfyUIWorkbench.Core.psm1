Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function New-CuwException {
    param([string]$Message, [int]$ExitCode = 1)
    $exception = New-Object System.Exception($Message)
    $exception.Data['ExitCode'] = $ExitCode
    return $exception
}

function Throw-CuwError {
    param([string]$Message, [int]$ExitCode = 1)
    throw (New-CuwException -Message $Message -ExitCode $ExitCode)
}

function Get-CuwExitCode {
    param($Exception)
    if ($null -ne $Exception -and $Exception.Data.Contains('ExitCode')) {
        return [int]$Exception.Data['ExitCode']
    }
    return 1
}

function Resolve-CuwDataRoot {
    param([Parameter(Mandatory = $true)][string]$Path)
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    return [IO.Path]::GetFullPath($expanded)
}

function Get-CuwPaths {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][string]$DataRoot
    )
    $repo = [IO.Path]::GetFullPath($RepositoryRoot)
    $data = Resolve-CuwDataRoot -Path $DataRoot
    $runtime = Join-Path $data 'runtime'
    $userdata = Join-Path $data 'userdata'
    $models = Join-Path $userdata 'models'
    $user = Join-Path $userdata 'user'
    return [pscustomobject]@{
        RepositoryRoot = $repo
        DataRoot = $data
        RuntimeRoot = $runtime
        VersionsRoot = Join-Path $runtime 'versions'
        VersionRoot = Join-Path $runtime 'versions\comfyui-v0.37.0-nvidia'
        DownloadsRoot = Join-Path $data 'downloads'
        StateRoot = Join-Path $data 'state'
        LogsRoot = Join-Path $data 'logs'
        StatePath = Join-Path $data 'state\runtime.json'
        UserDataRoot = $userdata
        ModelsRoot = $models
        CheckpointsRoot = Join-Path $models 'checkpoints'
        LoraRoot = Join-Path $models 'loras'
        VaeRoot = Join-Path $models 'vae'
        DiffusionModelsRoot = Join-Path $models 'diffusion_models'
        TextEncodersRoot = Join-Path $models 'text_encoders'
        ControlNetRoot = Join-Path $models 'controlnet'
        CustomNodesRoot = Join-Path $userdata 'custom_nodes'
        InputRoot = Join-Path $userdata 'input'
        OutputRoot = Join-Path $userdata 'output'
        WorkflowsRoot = Join-Path $user 'default\workflows'
        UserRoot = $user
        TempRoot = Join-Path $userdata 'temp'
        LockPath = Join-Path $repo 'configs\upstream-lock.json'
    }
}

function Initialize-CuwLayout {
    param([Parameter(Mandatory = $true)]$Paths)
    $directories = @(
        $Paths.DataRoot, $Paths.RuntimeRoot, $Paths.VersionsRoot, $Paths.DownloadsRoot,
        $Paths.StateRoot, $Paths.LogsRoot, $Paths.UserDataRoot, $Paths.ModelsRoot,
        $Paths.CheckpointsRoot, $Paths.LoraRoot, $Paths.VaeRoot,
        $Paths.DiffusionModelsRoot, $Paths.TextEncodersRoot, $Paths.ControlNetRoot,
        $Paths.CustomNodesRoot, $Paths.InputRoot, $Paths.OutputRoot,
        $Paths.WorkflowsRoot, $Paths.UserRoot, $Paths.TempRoot
    )
    foreach ($directory in $directories) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $directory -Force
        }
    }
}

function Read-CuwJson {
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$Optional)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        if ($Optional) { return $null }
        Throw-CuwError -Message ("Required file is missing: {0}" -f $Path) -ExitCode 3
    }
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Throw-CuwError -Message ("Cannot read JSON file: {0}. {1}" -f $Path, $_.Exception.Message) -ExitCode 3
    }
}

function Write-CuwJsonAtomic {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }
    $temporary = $Path + '.tmp'
    $encoding = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 10), $encoding)
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-CuwRuntimeInfo {
    param([Parameter(Mandatory = $true)]$Paths)
    if (-not (Test-Path -LiteralPath $Paths.VersionRoot -PathType Container)) { return $null }
    $main = Get-ChildItem -LiteralPath $Paths.VersionRoot -File -Filter 'main.py' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[\\/]ComfyUI[\\/]main\.py$' } | Select-Object -First 1
    $python = Get-ChildItem -LiteralPath $Paths.VersionRoot -File -Filter 'python.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -match 'python_embed' } | Select-Object -First 1
    if ($null -eq $main -or $null -eq $python) { return $null }
    return [pscustomobject]@{
        MainPath = $main.FullName
        ComfyRoot = $main.DirectoryName
        PythonPath = $python.FullName
        PortableRoot = Split-Path -Parent $python.DirectoryName
    }
}

function Get-CuwFileHashValue {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-CuwDownload {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    $partial = $Destination + '.partial'
    if (Test-Path -LiteralPath $partial -PathType Leaf) { Remove-Item -LiteralPath $partial -Force }
    Write-Output ("正在下载官方 ComfyUI 便携运行环境：{0}" -f $Url)
    $bits = Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue
    if ($null -ne $bits) {
        Start-BitsTransfer -Source $Url -Destination $partial -DisplayName 'ComfyUI Workbench runtime'
    }
    else {
        $client = New-Object Net.WebClient
        try { $client.DownloadFile($Url, $partial) }
        finally { $client.Dispose() }
    }
    Move-Item -LiteralPath $partial -Destination $Destination -Force
}

function Invoke-CuwSetup {
    param([Parameter(Mandatory = $true)]$Paths)
    if ($env:OS -ne 'Windows_NT') {
        Throw-CuwError -Message '当前启动器只支持 Windows。' -ExitCode 2
    }
    if ((Get-CuwGpuSummary) -match '^未检测') {
        Throw-CuwError -Message '当前版本需要 NVIDIA 显卡；未检测到可用的 NVIDIA 驱动。' -ExitCode 2
    }
    Initialize-CuwLayout -Paths $Paths
    $lock = Read-CuwJson -Path $Paths.LockPath
    $asset = $lock.comfyui.windowsNvidia
    $runtime = Get-CuwRuntimeInfo -Paths $Paths
    if ($null -ne $runtime) {
        Write-Output ("工作台已经准备完成：ComfyUI {0}" -f $lock.comfyui.version)
        return
    }
    $archive = Join-Path $Paths.DownloadsRoot ([string]$asset.fileName)
    if (Test-Path -LiteralPath $archive -PathType Leaf) {
        $actual = Get-CuwFileHashValue -Path $archive
        if ($actual -ne ([string]$asset.sha256).ToLowerInvariant()) {
            Remove-Item -LiteralPath $archive -Force
        }
    }
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        Invoke-CuwDownload -Url ([string]$asset.url) -Destination $archive
    }
    Write-Output '正在校验下载文件…'
    $actualHash = Get-CuwFileHashValue -Path $archive
    if ($actualHash -ne ([string]$asset.sha256).ToLowerInvariant()) {
        Throw-CuwError -Message '下载文件校验失败。请删除 downloads 中的文件后重试。' -ExitCode 4
    }
    $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
    if ($null -eq $tar) { Throw-CuwError -Message 'Windows 未提供 tar 解压工具。请更新 Windows 后重试。' -ExitCode 3 }
    $staging = Join-Path $Paths.RuntimeRoot ('staging-' + [Guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $staging -Force
    try {
        Write-Output '正在解压隔离运行环境…'
        & $tar.Source -xf $archive -C $staging
        if ($LASTEXITCODE -ne 0) { Throw-CuwError -Message 'ComfyUI 便携包解压失败。' -ExitCode 4 }
        $main = Get-ChildItem -LiteralPath $staging -File -Filter 'main.py' -Recurse |
            Where-Object { $_.FullName -match '[\\/]ComfyUI[\\/]main\.py$' } | Select-Object -First 1
        if ($null -eq $main) { Throw-CuwError -Message '便携包中没有找到 ComfyUI 主程序。' -ExitCode 4 }
        $portableRoot = Split-Path -Parent $main.DirectoryName
        $python = Get-ChildItem -LiteralPath $portableRoot -File -Filter 'python.exe' -Recurse |
            Where-Object { $_.DirectoryName -match 'python_embed' } | Select-Object -First 1
        if ($null -eq $python) { Throw-CuwError -Message '便携包中没有找到隔离 Python。' -ExitCode 4 }
        if (Test-Path -LiteralPath $Paths.VersionRoot) {
            Throw-CuwError -Message '目标运行目录已经存在但不完整，请运行检查问题。' -ExitCode 4
        }
        Move-Item -LiteralPath $portableRoot -Destination $Paths.VersionRoot
        Write-CuwJsonAtomic -Path (Join-Path $Paths.VersionRoot 'workbench-install.json') -Value ([ordered]@{
            version = [string]$lock.comfyui.version
            sha256 = [string]$asset.sha256
            installedAt = [DateTime]::UtcNow.ToString('o')
        })
    }
    finally {
        if (Test-Path -LiteralPath $staging -PathType Container) {
            Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    if ($null -eq (Get-CuwRuntimeInfo -Paths $Paths)) {
        Throw-CuwError -Message '运行环境安装后验证失败。' -ExitCode 4
    }
    Write-Output '工作台准备完成。无需配置系统 Python。'
}

function ConvertTo-CuwCommandLineArgument {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Test-CuwHealth {
    param([int]$Port = 8188)
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri ("http://127.0.0.1:{0}/system_stats" -f $Port) -TimeoutSec 3
        return $response.StatusCode -eq 200
    }
    catch { return $false }
}

function Read-CuwState {
    param([Parameter(Mandatory = $true)]$Paths)
    return Read-CuwJson -Path $Paths.StatePath -Optional
}

function Test-CuwOwnedProcess {
    param([Parameter(Mandatory = $true)]$Paths, $State)
    if ($null -eq $State -or $null -eq $State.pid) { return $false }
    $process = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f [int]$State.pid) -ErrorAction SilentlyContinue
    if ($null -eq $process -or [string]::IsNullOrWhiteSpace([string]$process.CommandLine)) { return $false }
    $runtime = Get-CuwRuntimeInfo -Paths $Paths
    if ($null -eq $runtime) { return $false }
    return $process.CommandLine.IndexOf($runtime.MainPath, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Test-CuwPortAvailable {
    param([int]$Port)
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
    try { $listener.Start(); return $true }
    catch { return $false }
    finally { try { $listener.Stop() } catch {} }
}

function Invoke-CuwStart {
    param([Parameter(Mandatory = $true)]$Paths, [int]$Port = 8188)
    Initialize-CuwLayout -Paths $Paths
    $runtime = Get-CuwRuntimeInfo -Paths $Paths
    if ($null -eq $runtime) { Throw-CuwError -Message '工作台还没有准备好。请先点击“准备工作台”。' -ExitCode 3 }
    $state = Read-CuwState -Paths $Paths
    if ((Test-CuwOwnedProcess -Paths $Paths -State $state) -and (Test-CuwHealth -Port $Port)) {
        Write-Output ("创作服务已经运行：http://127.0.0.1:{0}" -f $Port)
        return
    }
    if (-not (Test-CuwPortAvailable -Port $Port)) {
        Throw-CuwError -Message ("端口 {0} 已被其他程序占用。" -f $Port) -ExitCode 5
    }
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $stdout = Join-Path $Paths.LogsRoot ("comfyui-{0}.log" -f $timestamp)
    $stderr = Join-Path $Paths.LogsRoot ("comfyui-{0}.error.log" -f $timestamp)
    $arguments = @(
        '-s', $runtime.MainPath,
        '--windows-standalone-build',
        '--listen', '127.0.0.1',
        '--port', [string]$Port,
        '--disable-auto-launch',
        '--disable-api-nodes',
        '--base-directory', $Paths.UserDataRoot,
        '--user-directory', $Paths.UserRoot,
        '--input-directory', $Paths.InputRoot,
        '--output-directory', $Paths.OutputRoot,
        '--temp-directory', $Paths.TempRoot
    )
    $argumentLine = (($arguments | ForEach-Object { ConvertTo-CuwCommandLineArgument -Value ([string]$_) }) -join ' ')
    Write-Output ("正在启动创作服务：http://127.0.0.1:{0}" -f $Port)
    $process = Start-Process -FilePath $runtime.PythonPath -ArgumentList $argumentLine -WorkingDirectory $runtime.ComfyRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    Write-CuwJsonAtomic -Path $Paths.StatePath -Value ([ordered]@{
        pid = $process.Id
        port = $Port
        startedAt = [DateTime]::UtcNow.ToString('o')
        mainPath = $runtime.MainPath
        logPath = $stdout
        errorLogPath = $stderr
    })
    $deadline = [DateTime]::UtcNow.AddMinutes(4)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($process.HasExited) {
            $tail = ''
            if (Test-Path -LiteralPath $stderr) { $tail = (Get-Content -LiteralPath $stderr -Tail 20 -ErrorAction SilentlyContinue) -join [Environment]::NewLine }
            Throw-CuwError -Message ("创作服务启动失败。{0}" -f $tail) -ExitCode 6
        }
        if (Test-CuwHealth -Port $Port) {
            Write-Output ("创作服务已就绪：http://127.0.0.1:{0}" -f $Port)
            return
        }
        Start-Sleep -Seconds 1
    }
    Throw-CuwError -Message '创作服务启动超时，请运行“检查问题”。' -ExitCode 6
}

function Invoke-CuwStop {
    param([Parameter(Mandatory = $true)]$Paths)
    $state = Read-CuwState -Paths $Paths
    if (-not (Test-CuwOwnedProcess -Paths $Paths -State $state)) {
        Write-Output '创作服务没有运行。'
        return
    }
    $process = Get-Process -Id ([int]$state.pid) -ErrorAction SilentlyContinue
    if ($null -eq $process) { Write-Output '创作服务没有运行。'; return }
    try { Invoke-RestMethod -Method Post -Uri ("http://127.0.0.1:{0}/interrupt" -f [int]$state.port) -TimeoutSec 3 | Out-Null } catch {}
    Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
    try { Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue } catch {}
    if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) { Stop-Process -Id $process.Id -Force }
    Write-Output '创作服务已停止。'
}

function Get-CuwGpuSummary {
    $nvidia = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($null -eq $nvidia) { return '未检测到 NVIDIA 显卡' }
    try {
        $line = & $nvidia.Source --query-gpu=name,memory.total --format=csv,noheader,nounits 2>$null | Select-Object -First 1
        if ($line -match '^\s*(.+),\s*(\d+)\s*$') { return ("{0} · {1:N1} GB 显存" -f $matches[1].Trim(), ([double]$matches[2] / 1024)) }
    }
    catch {}
    return 'NVIDIA 显卡'
}

function Get-CuwSummary {
    param([Parameter(Mandatory = $true)]$Paths, [int]$Port = 8188)
    Initialize-CuwLayout -Paths $Paths
    $runtime = Get-CuwRuntimeInfo -Paths $Paths
    $state = Read-CuwState -Paths $Paths
    $owned = Test-CuwOwnedProcess -Paths $Paths -State $state
    $healthy = $false
    if ($owned) { $healthy = Test-CuwHealth -Port $Port }
    $status = 'notReady'
    $message = '需要准备工作台'
    if ($null -ne $runtime) { $status = 'ready'; $message = '可以开始创作' }
    if ($owned -and -not $healthy) { $status = 'starting'; $message = '创作服务正在启动' }
    if ($healthy) { $status = 'running'; $message = '创作服务正在运行' }
    return [pscustomobject]@{
        Status = $status
        Message = $message
        Installed = $null -ne $runtime
        Running = $healthy
        Url = ("http://127.0.0.1:{0}" -f $Port)
        DataRoot = $Paths.DataRoot
        Gpu = Get-CuwGpuSummary
        CheckpointCount = @(Get-ChildItem -LiteralPath $Paths.CheckpointsRoot -File -Recurse -Include '*.safetensors','*.ckpt' -ErrorAction SilentlyContinue).Count
        WorkflowCount = @(Get-ChildItem -LiteralPath $Paths.WorkflowsRoot -File -Recurse -Filter '*.json' -ErrorAction SilentlyContinue).Count
    }
}

function Invoke-CuwDoctor {
    param([Parameter(Mandatory = $true)]$Paths, [int]$Port = 8188)
    $failures = 0
    if ($env:OS -eq 'Windows_NT') { Write-Output '[通过] 系统：Windows' } else { Write-Output '[失败] 系统：当前启动器只支持 Windows'; $failures++ }
    $gpu = Get-CuwGpuSummary
    if ($gpu -match '^未检测') { Write-Output ("[失败] 显卡：{0}" -f $gpu); $failures++ } else { Write-Output ("[通过] 显卡：{0}" -f $gpu) }
    $drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($Paths.DataRoot).Substring(0,1)) -ErrorAction SilentlyContinue
    if ($null -ne $drive) { Write-Output ("[通过] 存储空间：剩余 {0:N1} GB" -f ($drive.Free / 1GB)) }
    $runtime = Get-CuwRuntimeInfo -Paths $Paths
    if ($null -ne $runtime) {
        Write-Output '[通过] 运行环境：隔离 Python 和 ComfyUI 文件完整'
        $version = & $runtime.PythonPath --version 2>&1
        Write-Output ("[通过] 私有 Python：{0}" -f $version)
    }
    else { Write-Output '[失败] 运行环境：尚未准备或文件不完整'; $failures++ }
    $summary = Get-CuwSummary -Paths $Paths -Port $Port
    if ($summary.Running) { Write-Output ("[通过] 创作服务：{0}" -f $summary.Url) }
    elseif (Test-CuwPortAvailable -Port $Port) { Write-Output '[通过] 服务端口：可用' }
    else { Write-Output ("[失败] 服务端口：{0} 被其他程序占用" -f $Port); $failures++ }
    Write-Output ("检查完成：{0} 个问题。" -f $failures)
    if ($failures -gt 0) { Throw-CuwError -Message '检查发现需要处理的问题。' -ExitCode 7 }
}

function Open-CuwPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { $null = New-Item -ItemType Directory -Path $Path -Force }
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $Path)
}

Export-ModuleMember -Function @(
    'New-CuwException','Get-CuwExitCode','Resolve-CuwDataRoot','Get-CuwPaths','Initialize-CuwLayout',
    'Read-CuwJson','Write-CuwJsonAtomic','Get-CuwRuntimeInfo','Get-CuwFileHashValue','Invoke-CuwSetup',
    'Test-CuwHealth','Invoke-CuwStart','Invoke-CuwStop','Get-CuwGpuSummary','Get-CuwSummary','Invoke-CuwDoctor','Open-CuwPath'
)
