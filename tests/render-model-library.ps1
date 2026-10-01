[CmdletBinding()]
param([string]$OutputPath = (Join-Path $env:TEMP 'comfyui-workbench-model-library.png'))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repositoryRoot 'src\ComfyUIWorkbench.Core.psm1') -Force
$paths = Get-CuwPaths -RepositoryRoot $repositoryRoot -DataRoot (Join-Path $repositoryRoot 'data')
$catalog = @(Get-CuwModelCatalog -Paths $paths)
[xml]$xaml = Get-Content -LiteralPath (Join-Path $repositoryRoot 'launcher\ModelLibrary.xaml') -Raw -Encoding UTF8
$reader = New-Object Xml.XmlNodeReader($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.WindowStyle = 'None'
$window.ResizeMode = 'NoResize'
$window.ShowInTaskbar = $false
$window.Left = -20000
$window.Top = -20000
$window.Width = 880
$window.Height = 620
$items = foreach ($model in $catalog) {
    $state = Get-CuwModelState -Paths $paths -Model $model
    [pscustomobject]@{ ListLabel = [string]$model.displayName; Model = $model; State = $state }
}
$list = $window.FindName('ModelList')
$list.ItemsSource = @($items)
if (@($items).Count -gt 0) {
    $item = @($items)[0]
    $model = $item.Model
    $list.SelectedIndex = 0
    $window.FindName('ModelNameText').Text = [string]$model.displayName
    $window.FindName('ModelFamilyText').Text = [string]$model.family
    $window.FindName('ModelSummaryText').Text = [string]$model.summary
    $window.FindName('ModelHardwareText').Text = [string]$model.hardwareNote
    $window.FindName('ModelSizeText').Text = Format-CuwByteSize -Bytes ([long]$model.sizeBytes)
    $window.FindName('ModelLicenseText').Text = [string]$model.license.id
    $window.FindName('ModelLicenseNoteText').Text = [string]$model.license.summaryZh
    $window.FindName('ModelStatusText').Text = [string]$item.State.Message
    if ($item.State.Status -eq 'installed') {
        $window.FindName('ModelStatusPill').Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#DCFCE7')
        $window.FindName('ModelStatusText').Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#167044')
        $window.FindName('ModelDownloadButton').Content = '已经安装'
        $window.FindName('ModelDownloadButton').IsEnabled = $false
    }
}
$window.Show()
$window.UpdateLayout()
$bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap(880, 620, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($window)
$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$stream = [IO.File]::Open($OutputPath, [IO.FileMode]::Create)
try { $encoder.Save($stream) } finally { $stream.Dispose() }
$window.Close()
Write-Output $OutputPath
