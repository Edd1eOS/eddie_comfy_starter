function Get-CuwModelPathTypes {
    @(
        [pscustomobject]@{ Key='checkpoints'; Label='主模型 · checkpoints'; Description='决定基本画风和生成能力的整套模型。' }
        [pscustomobject]@{ Key='controlnet'; Label='画面控制 · controlnet'; Description='让生成画面跟随指定的姿势、轮廓或构图。' }
        [pscustomobject]@{ Key='diffusion_models'; Label='生成核心 · diffusion_models'; Description='负责生成图片或视频的核心模型，通常要搭配文字编码器和 VAE。' }
        [pscustomobject]@{ Key='loras'; Label='风格与角色 · loras'; Description='给主模型增加特定画风、角色或细节的小模型。' }
        [pscustomobject]@{ Key='text_encoders'; Label='理解文字 · text_encoders'; Description='把提示词转换成生成模型能理解的信息。' }
        [pscustomobject]@{ Key='vae'; Label='画面转换 · vae'; Description='把图片和模型内部的压缩表示相互转换，生成时负责还原画面。' }
    )
}

function Get-CuwExternalModelPaths {
    param([Parameter(Mandatory=$true)]$Paths)
    $config = Read-CuwJson -Path (Join-Path $Paths.StateRoot 'model-paths.json') -Optional
    if ($null -ne $config) {
        if ($config.version -ne 1) { throw '模型路径配置版本不受支持。' }
        foreach ($entry in $config.entries) { $entry }
    }
}

function ConvertTo-CuwModelPathEntries {
    param([AllowEmptyCollection()][object[]]$Entries = @())
    $keys = @(Get-CuwModelPathTypes | ForEach-Object { $_.Key })
    $seen = @{}
    foreach ($entry in $Entries) {
        $kind = [string]$entry.type
        if ($kind -notin $keys) { throw "未知模型类型：$kind" }
        $raw = [string]$entry.path
        if ([string]::IsNullOrWhiteSpace($raw) -or $raw -match '[\r\n]') { throw '请选择有效的模型文件夹。' }
        $expanded = [Environment]::ExpandEnvironmentVariables($raw)
        if (-not [IO.Path]::IsPathRooted($expanded)) { throw '模型目录必须是完整路径。' }
        $full = [IO.Path]::GetFullPath($expanded)
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw "模型目录不存在或无法访问：$full" }
        $identity = $kind + '|' + $full.TrimEnd('\','/')
        if (-not $seen.ContainsKey($identity)) {
            $seen[$identity] = $true
            [pscustomobject]@{ type=$kind; path=$full }
        }
    }
}

function Save-CuwExternalModelPaths {
    param([Parameter(Mandatory=$true)]$Paths, [AllowEmptyCollection()][object[]]$Entries = @())
    $valid = @(ConvertTo-CuwModelPathEntries -Entries $Entries)
    Write-CuwJsonAtomic -Path (Join-Path $Paths.StateRoot 'model-paths.json') -Value ([ordered]@{ version=1; entries=$valid })
}

function Update-CuwExtraModelPaths {
    param([Parameter(Mandatory=$true)]$Paths)
    $entries = @(ConvertTo-CuwModelPathEntries -Entries @(Get-CuwExternalModelPaths -Paths $Paths))
    if ($entries.Count -eq 0) { return $null }
    $mapping = [ordered]@{}
    $i = 0
    foreach ($entry in $entries) {
        $group = [ordered]@{ base_path=$entry.path }
        $group[$entry.type] = '.'
        $mapping[('workbench_external_{0}' -f $i)] = $group
        $i++
    }
    # JSON is valid YAML; escaping is handled by the serializer, not string concatenation.
    $target = Join-Path $Paths.StateRoot 'extra-model-paths.yaml'
    Write-CuwJsonAtomic -Path $target -Value $mapping
    return $target
}
