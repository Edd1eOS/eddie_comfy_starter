$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$repo = Split-Path -Parent $PSScriptRoot
[xml]$xaml = Get-Content -LiteralPath (Join-Path $repo 'launcher\ComfyUIWorkbench.xaml') -Raw -Encoding UTF8
$window = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader($xaml)))
$buttons = @('ChangeStorageButton','PrimaryActionButton','StopButton','ModelLibraryButton','ModelsButton','ModelPathsButton','WorkflowsButton','OutputButton','DoctorButton','MinimizeWindowButton','MaximizeWindowButton','CloseWindowButton')
$script:clickCount = 0
foreach ($name in $buttons) {
    $button = $window.FindName($name)
    if ($null -eq $button -or -not $button.IsEnabled -or -not $button.Focusable -or -not $button.IsHitTestVisible) {
        throw "Button is missing or inaccessible: $name"
    }
    $button.Add_Click({ $script:clickCount++ })
    $button.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
}
if ($script:clickCount -ne $buttons.Count) { throw 'Button click events did not propagate' }
foreach ($name in @('StatusPill','StatusText','HeroTitle','HeroDescription','GpuText','StorageText','CountsText','LogExpander','BusyBar','LogText')) {
    if ($null -eq $window.FindName($name)) { throw "Missing controller binding: $name" }
}
$decorations = $xaml.SelectNodes("//*[local-name()='Canvas']")
foreach ($decoration in $decorations) {
    if ($decoration.GetAttribute('IsHitTestVisible') -ne 'False') { throw 'Decoration intercepts input' }
}
$chrome = [Windows.Shell.WindowChrome]::GetWindowChrome($window)
if ($window.WindowStyle -ne 'None' -or $chrome.CaptionHeight -ne 82 -or $chrome.ResizeBorderThickness.Left -le 0) { throw 'Custom window chrome is not configured' }
foreach ($name in @('MinimizeWindowButton','MaximizeWindowButton','CloseWindowButton','ChangeStorageButton')) {
    if (-not [Windows.Shell.WindowChrome]::GetIsHitTestVisibleInChrome($window.FindName($name))) { throw "Chrome blocks $name" }
}
$sourcePath = Join-Path $repo 'launcher\ComfyUIWorkbench.ps1'
$parseErrors = $null
$tokens = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'Launcher script syntax error' }
$refresh = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Refresh-CuwLauncher' }, $true)
# Test only status rendering; never start services or launch the real controller.
Invoke-Expression $refresh.Extent.Text
function Get-CuwPaths { param($RepositoryRoot, $DataRoot) return @{} }
function Get-CuwSummary { param($Paths, $Port) return $script:previewSummary }
function Set-CuwLogText { param($Text) throw $Text }
foreach ($name in @('StatusPill','StatusText','HeroTitle','HeroDescription','GpuText','StorageText','CountsText','PrimaryActionButton','LogExpander')) {
    Set-Variable -Name $name -Value $window.FindName($name) -Scope Script
}
$script:previewSummary = [pscustomobject]@{ Message='Ready'; Gpu='Test GPU'; DataRoot='D:\Demo'; CheckpointCount=2; WorkflowCount=1; Status='ready'; Installed=$true }
Refresh-CuwLauncher
if ($script:HeroTitle.Text -ne '点击下面的按钮打开webui' -or $script:HeroDescription.Text -ne '本地离线运行的工作站，已完成环境配置和依赖打包') { throw 'Stopped-ready copy mismatch' }
$script:previewSummary.Status = 'running'
Refresh-CuwLauncher
if ($script:HeroTitle.Text -ne '创作界面已经准备好') { throw 'Running state changed' }
$script:previewSummary.Status = 'notReady'
$script:previewSummary.Installed = $false
Refresh-CuwLauncher
if ($script:HeroTitle.Text -ne '先准备工作台' -or $script:PrimaryActionButton.Content -ne '准备工作台') { throw 'Missing environment must retain setup guidance' }
$window.Close()
Write-Output 'PASS: installed/stopped, running and not-installed status copy; launcher script syntax.'
Write-Output 'PASS: 12 accessible buttons and click events; 10 status bindings; draggable/resizable custom chrome; valid WPF XAML.'
