function Get-CuwHardwareProfiles {
    param([string]$RepositoryRoot)
    return (Read-CuwJson (Join-Path $RepositoryRoot 'configs\hardware-profiles.json')).profiles
}

function Set-CuwHardwareProfile {
    param($Paths, [string]$ProfileId)
    $profile = @(Get-CuwHardwareProfiles $Paths.RepositoryRoot | Where-Object { $_.id -eq $ProfileId })
    if ($profile.Count -ne 1) { throw 'Unknown hardware profile.' }
    if (Test-CuwOwnedProcess -Paths $Paths -State (Read-CuwState $Paths)) {
        throw '请先停止创作服务，再切换硬件环境。'
    }
    Write-CuwJsonAtomic (Join-Path $Paths.DataRoot 'hardware.json') ([ordered]@{ profile = $ProfileId })
}

function Invoke-CuwBackendEnvironment {
    param($Paths, [scriptblock]$Action)
    if ($Paths.Hardware.backend -ne 'xpu') { return (& $Action) }
    # Child processes inherit these values. Restore the launcher process afterwards;
    # never write user/machine environment variables or modify system Python.
    $values = @{ SYCL_CACHE_PERSISTENT = '1'; SYCL_CACHE_DIR = (Join-Path $Paths.DataRoot 'cache\intel-sycl') }
    New-Item -ItemType Directory -Path $values.SYCL_CACHE_DIR -Force | Out-Null
    $previous = @{}
    try {
        foreach ($key in $values.Keys) {
            $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
            [Environment]::SetEnvironmentVariable($key, $values[$key], 'Process')
        }
        & $Action
    } finally {
        foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
    }
}

function Test-CuwCompute {
    param($Paths, [ValidateRange(1,1800)][int]$TimeoutSeconds = 240)
    $runtime = Get-CuwRuntimeInfo $Paths
    if ($null -eq $runtime) { throw '运行环境尚未安装。' }
    $probe = Join-Path $Paths.RepositoryRoot 'scripts\probe-hardware.py'
    New-Item -ItemType Directory -Path $Paths.LogsRoot -Force | Out-Null
    $logBase = Join-Path $Paths.LogsRoot ('compute-' + [guid]::NewGuid().ToString('N'))
    $success = $false
    $result = @()
    try {
        $probeArguments = @('-s', '-u', $probe, $Paths.Hardware.backend) | ForEach-Object { ConvertTo-CuwCommandLineArgument ([string]$_) }
        Write-Output '正在检查计算能力…'
        if ($Paths.Hardware.backend -eq 'xpu') { Write-Output 'Intel 首次编译可能需要数分钟；检测日志保存在 logs 目录。' }
        $process = Invoke-CuwBackendEnvironment $Paths {
            Start-Process -FilePath $runtime.PythonPath -ArgumentList ($probeArguments -join ' ') -WindowStyle Hidden -RedirectStandardOutput ($logBase + '.log') -RedirectStandardError ($logBase + '.error.log') -PassThru
        }
        # Retain a process handle before waiting so Windows PowerShell can read ExitCode.
        $null = $process.Handle
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            # Only terminate the exact probe process that we just created.
            $process.Kill()
            $process.WaitForExit()
            $result += "计算检测超过 $TimeoutSeconds 秒；未完成，不代表显卡完全不支持。请查看检测日志。"
        } else { $success = $process.ExitCode -eq 0 }
    } catch { $result += $_.Exception.Message }
    foreach ($path in @(($logBase + '.log'), ($logBase + '.error.log'))) {
        if (Test-Path -LiteralPath $path) { $result += Get-Content -LiteralPath $path -Encoding UTF8 }
    }
    Write-CuwJsonAtomic (Join-Path $Paths.VersionRoot ('compute-' + $Paths.Hardware.backend + '.json')) ([ordered]@{ success = $success; checkedAt = [DateTime]::UtcNow.ToString('o'); scope = 'operators-only'; logPath = ($logBase + '.log') })
    if (-not $success) {
        throw ("所选环境无法计算：{0}。请检查型号和驱动，或选择 CPU；不会自动降级。`n{1}" -f $Paths.Hardware.name, ($result -join "`n"))
    }
    Write-Output ($result -join "`n")
}
