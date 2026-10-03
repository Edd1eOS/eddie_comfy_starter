[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repositoryRoot 'src\ComfyUIWorkbench.Core.psm1'
$cliPath = Join-Path $repositoryRoot 'scripts\cuw.ps1'
$xamlPath = Join-Path $PSScriptRoot 'ComfyUIWorkbench.xaml'
$modelLibraryXamlPath = Join-Path $PSScriptRoot 'ModelLibrary.xaml'
Import-Module $modulePath -Force
. (Join-Path $repositoryRoot 'src\ComfyUIWorkbench.ModelPathsDialog.ps1')

$settingsRoot = Join-Path $env:LOCALAPPDATA 'ComfyUIWorkbench'
$portableMode = Test-Path -LiteralPath (Join-Path $repositoryRoot 'portable.mode')
if ($portableMode) { $settingsRoot = Join-Path $repositoryRoot 'data\launcher-settings' }
$settingsPath = Join-Path $settingsRoot 'settings.json'
if (-not (Test-Path -LiteralPath $settingsRoot -PathType Container)) { $null = New-Item -ItemType Directory -Path $settingsRoot -Force }
$script:DataRoot = Join-Path $repositoryRoot 'data'
$saved = Read-CuwJson -Path $settingsPath -Optional
if ($null -ne $saved -and -not [string]::IsNullOrWhiteSpace([string]$saved.dataRoot)) {
    $savedRoot = [string]$saved.dataRoot
    if ($portableMode -and -not [IO.Path]::IsPathRooted($savedRoot)) { $savedRoot = Join-Path $repositoryRoot $savedRoot }
    $script:DataRoot = Resolve-CuwDataRoot -Path $savedRoot
}
$script:Port = 8188
$script:ActionProcess = $null
$script:ActionName = ''
$script:ActionOut = ''
$script:ActionErr = ''
$script:LastOutput = ''

[xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
$reader = New-Object Xml.XmlNodeReader($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# WindowChrome retains native drag, double-click maximize and edge resizing.
$window.FindName('MinimizeWindowButton').Add_Click({ $window.WindowState = 'Minimized' })
$window.FindName('MaximizeWindowButton').Add_Click({
    if ($window.WindowState -eq 'Maximized') { $window.WindowState = 'Normal' }
    else { $window.WindowState = 'Maximized' }
})
$window.FindName('CloseWindowButton').Add_Click({ $window.Close() })

$names = @('StatusPill','StatusText','ChangeStorageButton','HeroTitle','HeroDescription','PrimaryActionButton','StopButton','GpuText','StorageText','ModelLibraryButton','ModelsButton','WorkflowsButton','OutputButton','CountsText','DoctorButton','LogExpander','BusyBar','LogText')
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

function Save-CuwLauncherSettings {
    $rootToSave = $script:DataRoot
    if ($portableMode -and $script:DataRoot.TrimEnd('\') -eq (Join-Path $repositoryRoot 'data')) { $rootToSave = 'data' }
    Write-CuwJsonAtomic -Path $settingsPath -Value ([ordered]@{ dataRoot = $rootToSave })
}

function Set-CuwLogText {
    param([string]$Text)
    $script:LogText.Text = $Text
    $script:LogText.ScrollToEnd()
}

function Refresh-CuwLauncher {
    try {
        $paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $script:DataRoot
        $summary = Get-CuwSummary -Paths $paths -Port $script:Port
        $script:StatusText.Text = $summary.Message
        $script:GpuText.Text = $summary.Gpu
        $window.FindName('HardwareProfileText').Text = '当前方案：' + $paths.Hardware.name
        $script:StorageText.Text = $summary.DataRoot
        $script:CountsText.Text = ("{0} 个主模型  ·  {1} 个工作流" -f $summary.CheckpointCount, $summary.WorkflowCount)
        if ($summary.Status -eq 'running') {
            $script:StatusPill.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#DCFCE7')
            $script:StatusText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#167044')
            $script:HeroTitle.Text = '创作界面已经准备好'
            $script:HeroDescription.Text = '打开 ComfyUI 后，可以选择工作流、模型和生成参数。所有计算都在本机完成。'
            $script:PrimaryActionButton.Content = '打开创作界面'
        }
        elseif ($summary.Installed) {
            $script:StatusPill.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#E8E7FF')
            $script:StatusText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#4D46B8')
            $script:HeroTitle.Text = '点击下面的按钮打开webui'
            $script:HeroDescription.Text = '本地离线运行的工作站，已完成环境配置和依赖打包'
            $script:PrimaryActionButton.Content = '打开创作界面'
        }
        else {
            $script:StatusPill.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFF4D8')
            $script:StatusText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#855F00')
            $script:HeroTitle.Text = '先准备工作台'
            $script:HeroDescription.Text = '先选择显卡或 CPU，再一键下载对应环境。Python 和所需组件保存在独立目录，不影响系统环境。'
            $script:PrimaryActionButton.Content = '准备工作台'
        }
    }
    catch {
        $script:StatusText.Text = '状态读取失败'
        Set-CuwLogText -Text $_.Exception.Message
        $script:LogExpander.IsExpanded = $true
    }
}

function Start-CuwLauncherAction {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [string[]]$AdditionalArguments = @()
    )
    if ($null -ne $script:ActionProcess -and -not $script:ActionProcess.HasExited) {
        [Windows.MessageBox]::Show('工作台正在执行另一项操作，请稍候。', 'ComfyUI Workbench', 'OK', 'Information') | Out-Null
        return
    }
    $tempRoot = Join-Path $env:TEMP 'ComfyUIWorkbench'
    if (-not (Test-Path -LiteralPath $tempRoot -PathType Container)) { $null = New-Item -ItemType Directory -Path $tempRoot -Force }
    $token = [Guid]::NewGuid().ToString('N')
    $script:ActionOut = Join-Path $tempRoot ($token + '.out.log')
    $script:ActionErr = Join-Path $tempRoot ($token + '.err.log')
    $script:ActionName = $DisplayName
    $argumentLine = ('-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" {1} -DataRoot "{2}" -Port {3}' -f $cliPath, $Command, $script:DataRoot, $script:Port)
    foreach ($argument in $AdditionalArguments) {
        $argumentLine += (' "{0}"' -f ([string]$argument).Replace('"', '\"'))
    }
    $script:ActionProcess = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $argumentLine -WindowStyle Hidden -RedirectStandardOutput $script:ActionOut -RedirectStandardError $script:ActionErr -PassThru
    $script:BusyBar.Visibility = 'Visible'
    $script:LogExpander.IsExpanded = $true
    Set-CuwLogText -Text ("正在执行：{0}…" -f $DisplayName)
}

function Show-CuwHardwareDialog {
    if ($null -ne $script:ActionProcess -and -not $script:ActionProcess.HasExited) {
        [Windows.MessageBox]::Show('请等待当前操作完成。', '安装环境') | Out-Null
        return
    }
    $paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $script:DataRoot
    [xml]$hardwareXaml = Get-Content (Join-Path $PSScriptRoot 'Hardware.xaml') -Raw -Encoding UTF8
    $dialog = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($hardwareXaml))
    $dialog.Owner = $window
    $selector = $dialog.FindName('HardwareSelector')
    $note = $dialog.FindName('HardwareNote')
    $dialog.FindName('DetectedText').Text = '检测到：' + (Get-CuwGpuSummary)
    $profiles = @(Get-CuwHardwareProfiles $repositoryRoot)
    $selector.ItemsSource = $profiles
    $selector.Add_SelectionChanged({ if ($selector.SelectedItem) { $note.Text = $selector.SelectedItem.note } })
    $selector.SelectedItem = $profiles | Where-Object { $_.id -eq $paths.Hardware.id }
    $dialog.FindName('CancelButton').Add_Click({ $dialog.Close() })
    $dialog.FindName('InstallButton').Add_Click({
        try {
            Set-CuwHardwareProfile -Paths $paths -ProfileId $selector.SelectedItem.id
            $dialog.DialogResult = $true
        } catch { [Windows.MessageBox]::Show($_.Exception.Message, '无法切换环境') | Out-Null }
    })
    if ($dialog.ShowDialog() -eq $true) {
        Refresh-CuwLauncher
        Start-CuwLauncherAction -Command 'setup' -DisplayName '配置并检查所选硬件环境'
    }
}

function Show-CuwModelLibrary {
    if ($null -ne $script:ActionProcess -and -not $script:ActionProcess.HasExited) {
        [Windows.MessageBox]::Show('工作台正在执行另一项操作，请稍候。', 'ComfyUI Workbench', 'OK', 'Information') | Out-Null
        return
    }
    $paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $script:DataRoot
    $catalog = Get-CuwModelCatalog -Paths $paths
    [xml]$libraryXaml = Get-Content -LiteralPath $modelLibraryXamlPath -Raw -Encoding UTF8
    $libraryReader = New-Object Xml.XmlNodeReader($libraryXaml)
    $modelWindow = [Windows.Markup.XamlReader]::Load($libraryReader)
    $modelWindow.Owner = $window
    $controlNames = @(
        'ModelList','ModelStatusPill','ModelStatusText','ModelNameText','ModelFamilyText','ModelSummaryText',
        'ModelHardwareText','ModelSizeText','ModelLicenseText','ModelLicenseNoteText','ModelSourceButton',
        'ModelFolderButton','ModelCloseButton','ModelDownloadButton'
    )
    $controls = @{}
    foreach ($controlName in $controlNames) { $controls[$controlName] = $modelWindow.FindName($controlName) }
    $items = @()
    foreach ($model in $catalog) {
        $state = Get-CuwModelState -Paths $paths -Model $model
        $items += [pscustomobject]@{
            ListLabel = [string]$model.displayName
            Model = $model
            State = $state
        }
    }
    $controls.ModelList.ItemsSource = $items
    $refreshSelection = {
        $selected = $controls.ModelList.SelectedItem
        if ($null -eq $selected) { return }
        $model = $selected.Model
        $state = Get-CuwModelState -Paths $paths -Model $model
        $selected.State = $state
        $controls.ModelNameText.Text = [string]$model.displayName
        $controls.ModelFamilyText.Text = [string]$model.family
        $controls.ModelSummaryText.Text = [string]$model.summary
        $controls.ModelHardwareText.Text = [string]$model.hardwareNote
        $controls.ModelSizeText.Text = Format-CuwByteSize -Bytes ([long]$model.sizeBytes)
        $controls.ModelLicenseText.Text = [string]$model.license.id
        $controls.ModelLicenseNoteText.Text = [string]$model.license.summaryZh
        $controls.ModelStatusText.Text = $state.Message
        if ($state.Status -eq 'installed') {
            $controls.ModelStatusPill.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#DCFCE7')
            $controls.ModelStatusText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#167044')
            $controls.ModelDownloadButton.Content = '已经安装'
            $controls.ModelDownloadButton.IsEnabled = $false
        }
        elseif ($state.Status -eq 'needs-attention') {
            $controls.ModelStatusPill.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#FDECEC')
            $controls.ModelStatusText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#A33A3A')
            $controls.ModelDownloadButton.Content = '查看并处理'
            $controls.ModelDownloadButton.IsEnabled = $true
        }
        else {
            $controls.ModelStatusPill.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#EEF1F7')
            $controls.ModelStatusText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#596579')
            $controls.ModelDownloadButton.Content = if ($state.Status -eq 'partial') { '继续下载' } else { '下载并安装' }
            $controls.ModelDownloadButton.IsEnabled = $true
        }
    }
    $controls.ModelList.Add_SelectionChanged($refreshSelection)
    $controls.ModelSourceButton.Add_Click({
        $selected = $controls.ModelList.SelectedItem
        if ($null -ne $selected) { Start-Process -FilePath ([string]$selected.Model.modelCard) }
    })
    $controls.ModelFolderButton.Add_Click({ Open-CuwPath -Path $paths.CheckpointsRoot })
    $controls.ModelCloseButton.Add_Click({ $modelWindow.Close() })
    $controls.ModelDownloadButton.Add_Click({
        $selected = $controls.ModelList.SelectedItem
        if ($null -eq $selected) { return }
        $model = $selected.Model
        $state = Get-CuwModelState -Paths $paths -Model $model
        if ($state.Status -eq 'installed') { return }
        if ($state.Status -eq 'needs-attention') {
            [Windows.MessageBox]::Show(("Checkpoints 文件夹中已有同名但不完整的文件。请先将它移出文件夹：`n`n{0}" -f $state.TargetPath), '需要处理同名文件', 'OK', 'Warning') | Out-Null
            return
        }
        $message = @(
            ("准备从 Hugging Face 下载：{0}" -f $model.displayName),
            ("下载大小：{0}" -f (Format-CuwByteSize -Bytes ([long]$model.sizeBytes))),
            ("许可证：{0}" -f $model.license.id),
            '',
            [string]$model.license.summaryZh,
            '',
            '继续即表示你同意遵守许可证及模型来源页的限制。'
        ) -join [Environment]::NewLine
        $answer = [Windows.MessageBox]::Show($message, '确认下载模型', 'YesNo', 'Information')
        if ($answer -ne [Windows.MessageBoxResult]::Yes) { return }
        $modelId = [string]$model.id
        if ($modelId -notmatch '^[a-z0-9-]+$') {
            [Windows.MessageBox]::Show('模型标识无效，请更新工作台。', 'ComfyUI Workbench', 'OK', 'Error') | Out-Null
            return
        }
        $modelWindow.Close()
        Start-CuwLauncherAction -Command 'download-model' -DisplayName ("下载 {0}" -f $model.displayName) -AdditionalArguments @('-ModelId', $modelId, '-AcceptLicense')
    })
    if ($items.Count -gt 0) { $controls.ModelList.SelectedIndex = 0 }
    $null = $modelWindow.ShowDialog()
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(750)
$timer.Add_Tick({
    if ($null -eq $script:ActionProcess) { return }
    $output = ''
    if (Test-Path -LiteralPath $script:ActionOut) { $output = Get-Content -LiteralPath $script:ActionOut -Raw -ErrorAction SilentlyContinue }
    $errorText = ''
    if (Test-Path -LiteralPath $script:ActionErr) { $errorText = Get-Content -LiteralPath $script:ActionErr -Raw -ErrorAction SilentlyContinue }
    $combined = ($output + [Environment]::NewLine + $errorText).Trim()
    if (-not [string]::IsNullOrWhiteSpace($combined) -and $combined -ne $script:LastOutput) {
        $script:LastOutput = $combined
        Set-CuwLogText -Text $combined
    }
    if ($script:ActionProcess.HasExited) {
        $exitCode = $script:ActionProcess.ExitCode
        $display = $script:ActionName
        $script:ActionProcess.Dispose()
        $script:ActionProcess = $null
        $script:BusyBar.Visibility = 'Collapsed'
        Refresh-CuwLauncher
        if ($exitCode -eq 0) {
            if ([string]::IsNullOrWhiteSpace($combined)) { Set-CuwLogText -Text ("完成：{0}" -f $display) }
        }
        else {
            $script:LogExpander.IsExpanded = $true
            [Windows.MessageBox]::Show(("{0}没有完成。请查看运行详情。" -f $display), 'ComfyUI Workbench', 'OK', 'Warning') | Out-Null
        }
    }
})
$timer.Start()

$script:PrimaryActionButton.Add_Click({
    $paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $script:DataRoot
    $summary = Get-CuwSummary -Paths $paths -Port $script:Port
    if ($summary.Installed) { Start-CuwLauncherAction -Command 'open-ui' -DisplayName '打开创作界面' }
    else { Show-CuwHardwareDialog }
})
$window.FindName('HardwareButton').Add_Click({ Show-CuwHardwareDialog })
$script:StopButton.Add_Click({ Start-CuwLauncherAction -Command 'stop' -DisplayName '停止运行' })
$script:DoctorButton.Add_Click({ Start-CuwLauncherAction -Command 'doctor' -DisplayName '检查问题' })
$script:ModelLibraryButton.Add_Click({ Show-CuwModelLibrary })
$script:ModelsButton.Add_Click({ Start-CuwLauncherAction -Command 'open-models' -DisplayName '打开模型文件夹' })
$window.FindName('ModelPathsButton').Add_Click({
    try {
        $paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $script:DataRoot
        Show-CuwModelPathsDialog -Owner $window -Paths $paths -XamlPath (Join-Path $PSScriptRoot 'ModelPaths.xaml')
    } catch { [Windows.MessageBox]::Show($_.Exception.Message, '模型路径设置', 'OK', 'Warning') | Out-Null }
})
$script:WorkflowsButton.Add_Click({ Start-CuwLauncherAction -Command 'open-workflows' -DisplayName '打开工作流文件夹' })
$script:OutputButton.Add_Click({ Start-CuwLauncherAction -Command 'open-output' -DisplayName '打开输出文件夹' })
$script:ChangeStorageButton.Add_Click({
    $paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot $script:DataRoot
    $summary = Get-CuwSummary -Paths $paths -Port $script:Port
    if ($summary.Running) {
        [Windows.MessageBox]::Show('请先停止运行，再更改存储位置。', 'ComfyUI Workbench', 'OK', 'Information') | Out-Null
        return
    }
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = '选择 ComfyUI 模型、工作流和输出文件的存储位置'
    $dialog.SelectedPath = $script:DataRoot
    if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        $script:DataRoot = Resolve-CuwDataRoot -Path $dialog.SelectedPath
        Save-CuwLauncherSettings
        Refresh-CuwLauncher
    }
    $dialog.Dispose()
})

$window.Add_Closed({ $timer.Stop() })
Refresh-CuwLauncher
$null = $window.ShowDialog()
