[CmdletBinding()]
param([string]$OutputPath = (Join-Path $env:TEMP 'comfyui-workbench-launcher.png'))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$xamlPath = Join-Path $repositoryRoot 'launcher\ComfyUIWorkbench.xaml'
[xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
$reader = New-Object Xml.XmlNodeReader($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.WindowStyle = 'None'
$window.ResizeMode = 'NoResize'
$window.ShowInTaskbar = $false
$window.Left = -20000
$window.Top = -20000
$window.Width = 1120
$window.Height = 760
$window.Show()
$window.UpdateLayout()
$bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap(1120, 760, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($window)
$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$stream = [IO.File]::Open($OutputPath, [IO.FileMode]::Create)
try { $encoder.Save($stream) } finally { $stream.Dispose() }
$window.Close()
Write-Output $OutputPath
