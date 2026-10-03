param([switch]$Smoke)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repo 'src\ComfyUIWorkbench.Core.psm1') -Force
$root = Join-Path $repo ('data\tests\hardware-' + [guid]::NewGuid().ToString('N'))
$profiles = @(Get-CuwHardwareProfiles $repo)
if ($profiles.Count -ne 5) { throw 'Missing profiles' }
$paths = Get-CuwPaths $repo $root
if ($paths.Hardware.id -ne 'nvidia') { throw 'Backward compatibility failed' }
$models = $paths.ModelsRoot
foreach ($profile in $profiles) {
    if ($profile.sha256 -notmatch '^[0-9a-f]{64}$') { throw 'Unpinned asset' }
    Set-CuwHardwareProfile $paths $profile.id
    $paths = Get-CuwPaths $repo $root
    if ($paths.Hardware.id -ne $profile.id -or $paths.ModelsRoot -ne $models) { throw 'Persistence or shared models failed' }
    if (-not $paths.VersionRoot.EndsWith('-' + $profile.runtime)) { throw 'Wrong runtime directory' }
    Invoke-CuwStop $paths
}
$rejected = $false
try { Set-CuwHardwareProfile $paths '../invalid' } catch { $rejected = $true }
if (-not $rejected) { throw 'Invalid profile accepted' }
Add-Type -AssemblyName PresentationFramework
[xml]$xaml = Get-Content (Join-Path $repo 'launcher\Hardware.xaml') -Raw -Encoding UTF8
$dialog = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
$selector = $dialog.FindName('HardwareSelector')
$selector.ItemsSource = $profiles
$selector.SelectedIndex = 2
if ($selector.SelectedItem.id -ne 'amd' -or $null -eq $dialog.FindName('InstallButton')) { throw 'Hardware UI failed' }
$dialog.Close()
Write-Output 'PASS: profiles, allowlist, persistence, shared paths, stopped lifecycle, WPF selection.'
if ($Smoke) {
    # Reuse existing private runtime without changing the user's selection, state or outputs.
    $existing = Get-CuwPaths $repo (Join-Path $repo 'data')
    $runtime = Get-CuwRuntimeInfo $existing
    if ($null -eq $runtime) { throw 'Smoke test requires the existing portable runtime' }
    $paths.VersionRoot = $existing.VersionRoot
    $paths.Hardware = $profiles | Where-Object { $_.id -eq 'cpu' }
    try {
        Invoke-CuwSetup $paths
        Invoke-CuwStart $paths -Port 18288
        $stats = Invoke-RestMethod http://127.0.0.1:18288/system_stats
        if ($stats.devices[0].type -ne 'cpu') { throw 'Service did not use CPU' }
        $blocked = $false
        try { Set-CuwHardwareProfile $paths amd } catch { $blocked = $true }
        if (-not $blocked) { throw 'Allowed switching a live service' }
        Invoke-CuwDoctor $paths -Port 18288
    } finally { Invoke-CuwStop $paths }
    # Explicitly verify a wrong backend is rejected, not silently downgraded.
    $paths.Hardware = $profiles | Where-Object { $_.id -eq 'intel' }
    $rejected = $false
    try { Test-CuwCompute $paths } catch { $rejected = $true; Write-Output $_.Exception.Message }
    if (-not $rejected) { throw 'Unexpected Intel backend availability in NVIDIA runtime' }
    $summary = Get-CuwSummary $paths -Port 18288
    if ($summary.Installed -or $summary.Status -ne 'needsCheck') { throw 'Failed probe reported ready' }
    Write-Output 'PASS: real CPU setup/start/health/doctor/stop; live-switch rejected; wrong-backend rejected.'
}
