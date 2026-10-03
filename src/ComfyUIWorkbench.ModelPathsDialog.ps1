function Show-CuwModelPathsDialog {
    param($Owner, $Paths, [string]$XamlPath)
    [xml]$markup = Get-Content -LiteralPath $XamlPath -Raw -Encoding UTF8
    $dialog = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader($markup)))
    $dialog.Owner = $Owner
    $selector = $dialog.FindName('TypeSelector')
    $description = $dialog.FindName('TypeDescription')
    $defaultPath = $dialog.FindName('DefaultPathText')
    $list = $dialog.FindName('ExternalPathsList')
    $entries = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
    foreach ($entry in @(Get-CuwExternalModelPaths -Paths $Paths)) { $entries.Add([pscustomobject]@{ type=[string]$entry.type; path=[string]$entry.path }) }
    $list.ItemsSource = $entries
    $selector.ItemsSource = @(Get-CuwModelPathTypes)
    $selector.Add_SelectionChanged({
        $selected = $selector.SelectedItem
        if ($null -ne $selected) {
            $description.Text = $selected.Description
            $defaultPath.Text = Join-Path $Paths.ModelsRoot $selected.Key
        }
    })
    $selector.SelectedIndex = 0
    $dialog.FindName('AddPathButton').Add_Click({
        $picker = New-Object Windows.Forms.FolderBrowserDialog
        $picker.Description = '选择实际存放这一类模型的文件夹（不是所有模型的上级目录）'
        $picker.ShowNewFolderButton = $false
        try {
            if ($picker.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
                $kind = $selector.SelectedItem.Key
                $folder = [IO.Path]::GetFullPath($picker.SelectedPath)
                $duplicate = @($entries | Where-Object { $_.type -eq $kind -and $_.path.TrimEnd('\','/') -eq $folder.TrimEnd('\','/') })
                if ($duplicate.Count -eq 0) { $entries.Add([pscustomobject]@{ type=$kind; path=$folder }) }
            }
        } finally { $picker.Dispose() }
    })
    $dialog.FindName('RemovePathButton').Add_Click({ if ($null -ne $list.SelectedItem) { $null = $entries.Remove($list.SelectedItem) } })
    $dialog.FindName('CancelPathsButton').Add_Click({ $dialog.DialogResult = $false })
    $dialog.FindName('SavePathsButton').Add_Click({
        try {
            Save-CuwExternalModelPaths -Paths $Paths -Entries @($entries | ForEach-Object { $_ })
            [Windows.MessageBox]::Show($dialog, '路径已保存。请在当前生成任务完成后，停止并重新启动创作服务，然后刷新 WebUI。不会自动中断任务，也不会移动或删除模型。', '模型路径设置', 'OK', 'Information') | Out-Null
            $dialog.DialogResult = $true
        } catch { [Windows.MessageBox]::Show($dialog, $_.Exception.Message, '无法保存路径', 'OK', 'Warning') | Out-Null }
    })
    $null = $dialog.ShowDialog()
}
