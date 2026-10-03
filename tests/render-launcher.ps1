[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $env:TEMP 'comfyui-workbench-launcher.png'),
    [int]$Width = 1120,
    [int]$Height = 760,
    [switch]$ExpandLogs,
    [switch]$ReadyPreview,
    [switch]$ModelPathsPreview,
    [switch]$HardwarePreview
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$xamlPath = Join-Path $repositoryRoot 'launcher\ComfyUIWorkbench.xaml'
if ($ModelPathsPreview) { $xamlPath = Join-Path $repositoryRoot 'launcher\ModelPaths.xaml' }
if ($HardwarePreview) { $xamlPath = Join-Path $repositoryRoot 'launcher\Hardware.xaml' }
[xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
$reader = New-Object Xml.XmlNodeReader($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.WindowStyle = 'None'
$window.ResizeMode = 'NoResize'
$window.ShowInTaskbar = $false
$window.Left = -20000
$window.Top = -20000
$window.Width = $Width
$window.Height = $Height
if ($HardwarePreview) {
    Import-Module (Join-Path $repositoryRoot 'src\ComfyUIWorkbench.Core.psm1') -Force
    $profiles = @(Get-CuwHardwareProfiles $repositoryRoot)
    $window.FindName('HardwareSelector').ItemsSource = $profiles
    $window.FindName('HardwareSelector').SelectedIndex = 2
    $window.FindName('HardwareNote').Text = $profiles[2].note
    $window.FindName('DetectedText').Text = '检测到：NVIDIA GeForce RTX 5070 Laptop GPU'
}
if ($ModelPathsPreview) {
    Import-Module (Join-Path $repositoryRoot 'src\ComfyUIWorkbench.Core.psm1') -Force
    $types = @(Get-CuwModelPathTypes)
    $window.FindName('TypeSelector').ItemsSource = $types
    $window.FindName('TypeSelector').SelectedIndex = 0
    $window.FindName('TypeDescription').Text = $types[0].Description
    $window.FindName('DefaultPathText').Text = Join-Path $repositoryRoot 'data\userdata\models\checkpoints'
}
if ($ReadyPreview) {
    $window.FindName('PrimaryActionButton').Content = '打开创作界面'
    $window.FindName('StatusText').Text = '环境已就绪'
}
if ($ExpandLogs) { $window.FindName('LogExpander').IsExpanded = $true }
$window.Show()
$window.UpdateLayout()
$bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap($Width, $Height, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($window)
$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$stream = [IO.File]::Open($OutputPath, [IO.FileMode]::Create)
try { $encoder.Save($stream) } finally { $stream.Dispose() }
$window.Close()
Write-Output $OutputPath
