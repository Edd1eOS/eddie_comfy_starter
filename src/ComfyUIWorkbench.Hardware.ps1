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

function Test-CuwCompute {
    param($Paths)
    $runtime = Get-CuwRuntimeInfo $Paths
    if ($null -eq $runtime) { throw '运行环境尚未安装。' }
    $probe = Join-Path $Paths.RepositoryRoot 'scripts\probe-hardware.py'
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $result = & $runtime.PythonPath -s $probe $Paths.Hardware.backend 2>&1
        $success = $LASTEXITCODE -eq 0
    } finally { $ErrorActionPreference = $previousPreference }
    Write-CuwJsonAtomic (Join-Path $Paths.VersionRoot ('compute-' + $Paths.Hardware.backend + '.json')) ([ordered]@{ success = $success; checkedAt = [DateTime]::UtcNow.ToString('o') })
    if (-not $success) {
        throw ("所选环境无法计算：{0}。请检查型号和驱动，或选择 CPU；不会自动降级。`n{1}" -f $Paths.Hardware.name, ($result -join "`n"))
    }
    Write-Output ($result -join "`n")
}
