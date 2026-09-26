[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repositoryRoot 'src\ComfyUIWorkbench.Core.psm1'
$cliPath = Join-Path $repositoryRoot 'scripts\cuw.ps1'
$xamlPath = Join-Path $PSScriptRoot 'ComfyUIWorkbench.xaml'
Import-Module $modulePath -Force

$settingsRoot = Join-Path $env:LOCALAPPDATA 'ComfyUIWorkbench'
$settingsPath = Join-Path $settingsRoot 'settings.json'
if (-not (Test-Path -LiteralPath $settingsRoot -PathType Container)) { $null = New-Item -ItemType Directory -Path $settingsRoot -Force }
$script:DataRoot = Join-Path $repositoryRoot 'data'
$saved = Read-CuwJson -Path $settingsPath -Optional
if ($null -ne $saved -and -not [string]::IsNullOrWhiteSpace([string]$saved.dataRoot)) {
    $script:DataRoot = Resolve-CuwDataRoot -Path ([string]$saved.dataRoot)
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

$names = @('StatusPill','StatusText','ChangeStorageButton','HeroTitle','HeroDescription','PrimaryActionButton','StopButton','GpuText','StorageText','ModelsButton','WorkflowsButton','OutputButton','CountsText','DoctorButton','LogExpander','BusyBar','LogText')
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

function Save-CuwLauncherSettings {
    Write-CuwJsonAtomic -Path $settingsPath -Value ([ordered]@{ dataRoot = $script:DataRoot })
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
            $script:HeroTitle.Text = '从一个工作流开始'
            $script:HeroDescription.Text = 'ComfyUI 用节点连接图片或视频的生成步骤。工作台负责环境、文件与启动，你不需要配置 Python。'
            $script:PrimaryActionButton.Content = '打开创作界面'
        }
        else {
            $script:StatusPill.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFF4D8')
            $script:StatusText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#855F00')
            $script:HeroTitle.Text = '先准备工作台'
            $script:HeroDescription.Text = '将下载约 1.8 GB 的官方 ComfyUI 便携环境。Python 和所需组件会保存在独立目录，不影响电脑里的开发环境。'
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
    param([Parameter(Mandatory = $true)][string]$Command, [Parameter(Mandatory = $true)][string]$DisplayName)
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
    $script:ActionProcess = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $argumentLine -WindowStyle Hidden -RedirectStandardOutput $script:ActionOut -RedirectStandardError $script:ActionErr -PassThru
    $script:BusyBar.Visibility = 'Visible'
    $script:LogExpander.IsExpanded = $true
    Set-CuwLogText -Text ("正在执行：{0}…" -f $DisplayName)
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
    else { Start-CuwLauncherAction -Command 'setup' -DisplayName '准备工作台' }
})
$script:StopButton.Add_Click({ Start-CuwLauncherAction -Command 'stop' -DisplayName '停止运行' })
$script:DoctorButton.Add_Click({ Start-CuwLauncherAction -Command 'doctor' -DisplayName '检查问题' })
$script:ModelsButton.Add_Click({ Start-CuwLauncherAction -Command 'open-models' -DisplayName '打开模型文件夹' })
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
