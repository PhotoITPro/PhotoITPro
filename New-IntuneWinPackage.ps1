<#
.Notes
FileName: New-IntuneWinPackage.ps1
Author: Rob Young
Contact: @photoitpro
Created:  2026-07-27  
Uploaded: 2026-07-28

.Description
    GUI wrapper for the Microsoft Win32 Content Prep Tool (IntuneWinAppUtil.exe).
    Packages a folder of install files into a .intunewin file, and lets you
    name the output file whatever you like.
.Notes
    Requires IntuneWinAppUtil.exe - download from:
    https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool

Usage:
    .\New-IntuneWinPackage.ps1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$settingsFile = Join-Path $PSScriptRoot "IntuneWinPackager.settings.json"

function Get-SafeFileName {
    param([string]$Name)
    $invalid = [System.IO.Path]::GetInvalidFileNameChars() -join ''
    $pattern = "[{0}]" -f [System.Text.RegularExpressions.Regex]::Escape($invalid)
    return ($Name -replace $pattern, '_')
}

function Find-IntuneWinAppUtil {
    if (Test-Path $settingsFile) {
        try {
            $saved = Get-Content $settingsFile -Raw | ConvertFrom-Json
            if ($saved.ToolPath -and (Test-Path $saved.ToolPath)) {
                return $saved.ToolPath
            }
        } catch { }
    }
    $candidates = @(
        (Join-Path $PSScriptRoot "IntuneWinAppUtil.exe"),
        "C:\Tools\IntuneWinAppUtil.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    $cmd = Get-Command "IntuneWinAppUtil.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return ""
}

function Save-ToolPath {
    param([string]$Path)
    @{ ToolPath = $Path } | ConvertTo-Json | Out-File -FilePath $settingsFile -Encoding ascii -Force
}

# ---------- Build the form ----------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Create .intunewin Package"
$form.Size = New-Object System.Drawing.Size(560, 440)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

function New-Row {
    param($labelText, $y)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $labelText
    $lbl.Location = New-Object System.Drawing.Point(10, $y)
    $lbl.Size = New-Object System.Drawing.Size(520, 20)
    $form.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(10, ($y + 20))
    $txt.Size = New-Object System.Drawing.Size(430, 24)
    $form.Controls.Add($txt)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Browse..."
    $btn.Location = New-Object System.Drawing.Point(450, ($y + 19))
    $btn.Size = New-Object System.Drawing.Size(80, 26)
    $form.Controls.Add($btn)

    return @{ TextBox = $txt; Button = $btn }
}

$pkgNameLbl = New-Object System.Windows.Forms.Label
$pkgNameLbl.Text = "Package name (the .intunewin file will be saved with this name):"
$pkgNameLbl.Location = New-Object System.Drawing.Point(10, 10)
$pkgNameLbl.Size = New-Object System.Drawing.Size(520, 20)
$form.Controls.Add($pkgNameLbl)

$txtPkgName = New-Object System.Windows.Forms.TextBox
$txtPkgName.Location = New-Object System.Drawing.Point(10, 30)
$txtPkgName.Size = New-Object System.Drawing.Size(520, 24)
$form.Controls.Add($txtPkgName)

$source = New-Row "Source folder (contains all the install files):" 65
$setup  = New-Row "Setup file (the file that runs the install, e.g. Install-Printer.ps1):" 130
$output = New-Row "Output folder (where the .intunewin file will be saved):" 195
$tool   = New-Row "IntuneWinAppUtil.exe location:" 260

$tool.TextBox.Text = Find-IntuneWinAppUtil

$source.Button.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $source.TextBox.Text = $dlg.SelectedPath
    }
})

$setup.Button.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "All files (*.*)|*.*"
    if ($source.TextBox.Text -and (Test-Path $source.TextBox.Text)) {
        $dlg.InitialDirectory = $source.TextBox.Text
    }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $setup.TextBox.Text = $dlg.FileName
    }
})

$output.Button.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $output.TextBox.Text = $dlg.SelectedPath
    }
})

$tool.Button.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "IntuneWinAppUtil.exe|IntuneWinAppUtil.exe|Executable (*.exe)|*.exe"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $tool.TextBox.Text = $dlg.FileName
    }
})

$statusLbl = New-Object System.Windows.Forms.Label
$statusLbl.Text = ""
$statusLbl.Location = New-Object System.Drawing.Point(10, 330)
$statusLbl.Size = New-Object System.Drawing.Size(520, 20)
$statusLbl.ForeColor = [System.Drawing.Color]::DarkBlue
$form.Controls.Add($statusLbl)

$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = "Create .intunewin"
$btnCreate.Location = New-Object System.Drawing.Point(10, 360)
$btnCreate.Size = New-Object System.Drawing.Size(150, 32)
$form.Controls.Add($btnCreate)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(380, 360)
$btnClose.Size = New-Object System.Drawing.Size(150, 32)
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

$btnCreate.Add_Click({

    $pkgName   = $txtPkgName.Text.Trim()
    $sourceDir = $source.TextBox.Text.Trim()
    $setupFile = $setup.TextBox.Text.Trim()
    $outputDir = $output.TextBox.Text.Trim()
    $toolPath  = $tool.TextBox.Text.Trim()

    if (-not $pkgName -or -not $sourceDir -or -not $setupFile -or -not $outputDir -or -not $toolPath) {
        [System.Windows.Forms.MessageBox]::Show("Please fill in every field before creating the package.", "Missing information", "OK", "Warning") | Out-Null
        return
    }
    if (-not (Test-Path $sourceDir)) {
        [System.Windows.Forms.MessageBox]::Show("Source folder does not exist.", "Error", "OK", "Error") | Out-Null
        return
    }
    if (-not (Test-Path $setupFile)) {
        [System.Windows.Forms.MessageBox]::Show("Setup file does not exist.", "Error", "OK", "Error") | Out-Null
        return
    }
    if (-not (Test-Path $toolPath)) {
        [System.Windows.Forms.MessageBox]::Show("IntuneWinAppUtil.exe was not found at that location.", "Error", "OK", "Error") | Out-Null
        return
    }
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Save-ToolPath -Path $toolPath

    $statusLbl.Text = "Working..."
    $btnCreate.Enabled = $false
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()

    $stdOutFile = [System.IO.Path]::GetTempFileName()
    $stdErrFile = [System.IO.Path]::GetTempFileName()

    try {
        $proc = Start-Process -FilePath $toolPath `
            -ArgumentList @("-c", "`"$sourceDir`"", "-s", "`"$setupFile`"", "-o", "`"$outputDir`"", "-q") `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdOutFile -RedirectStandardError $stdErrFile

        $stdOut = Get-Content $stdOutFile -Raw -ErrorAction SilentlyContinue
        $stdErr = Get-Content $stdErrFile -Raw -ErrorAction SilentlyContinue

        $setupBaseName = [System.IO.Path]::GetFileNameWithoutExtension($setupFile)
        $generatedFile = Join-Path $outputDir "$setupBaseName.intunewin"

        if ($proc.ExitCode -eq 0 -and (Test-Path $generatedFile)) {
            $safePkgName = Get-SafeFileName -Name $pkgName
            $finalFile = Join-Path $outputDir "$safePkgName.intunewin"

            if ($generatedFile -ne $finalFile) {
                if (Test-Path $finalFile) { Remove-Item $finalFile -Force }
                Move-Item -Path $generatedFile -Destination $finalFile -Force
            }

            $statusLbl.Text = "Done."
            $result = [System.Windows.Forms.MessageBox]::Show("Package created:`n$finalFile`n`nOpen the output folder?", "Success", "YesNo", "Information")
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                Start-Process explorer.exe -ArgumentList "`"$outputDir`""
            }
        } else {
            $statusLbl.Text = "Failed."
            [System.Windows.Forms.MessageBox]::Show("IntuneWinAppUtil.exe did not produce a package.`n`nExit code: $($proc.ExitCode)`n`n$stdOut`n$stdErr", "Error", "OK", "Error") | Out-Null
        }
    } catch {
        $statusLbl.Text = "Failed."
        [System.Windows.Forms.MessageBox]::Show("Something went wrong: $($_.Exception.Message)", "Error", "OK", "Error") | Out-Null
    } finally {
        Remove-Item $stdOutFile, $stdErrFile -ErrorAction SilentlyContinue
        $btnCreate.Enabled = $true
    }
})

[System.Windows.Forms.Application]::EnableVisualStyles()
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
