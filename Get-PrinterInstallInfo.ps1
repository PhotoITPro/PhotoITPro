<#

.NOTES
FileName: Get-PrinterInstallInfo.ps1
Author: Rob Young
Contact: @photoitpro
Created:  2026-07-25  
Uploaded: 2026-07-28

.DESCRIPTION
Reads an already-installed network printer on this PC and prints back the parameters
needed to redeploy it with Install-Printer.ps1.

For each printer it also builds a package folder (named after the printer) containing:
  - a copy of the driver files from the DriverStore
  - a text file (same name as the printer) with the ready-to-use install command

.USAGE
    .\Get-PrinterInstallInfo.ps1                       # lists all printers found
    .\Get-PrinterInstallInfo.ps1 -PrinterName "Factory Office Printer"
    .\Get-PrinterInstallInfo.ps1 -OutputPath "C:\Temp\PrinterPackages"
#>

param(
    [string]$PrinterName,
    [string]$OutputPath = ".\PrinterPackages"
)

function Get-SafeFileName {
    param([string]$Name)
    $invalid = [System.IO.Path]::GetInvalidFileNameChars() -join ''
    $pattern = "[{0}]" -f [System.Text.RegularExpressions.Regex]::Escape($invalid)
    return ($Name -replace $pattern, '_')
}

$printers = if ($PrinterName) {
    Get-Printer -Name $PrinterName -ErrorAction Stop
} else {
    Get-Printer | Where-Object {
        $_.Type -eq 'Local' -and $_.PortName -notmatch '^(PORTPROMPT|FILE|nul|XPSPort)'
    }
}

if (-not $printers) {
    Write-Warning "No matching printers found."
    return
}

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

foreach ($printer in $printers) {

    $port   = Get-PrinterPort -Name $printer.PortName -ErrorAction SilentlyContinue
    $driver = Get-PrinterDriver -Name $printer.DriverName -ErrorAction SilentlyContinue

    $infFile    = $null
    $driverPath = $null
    if ($driver -and $driver.InfPath) {
        $infFile    = Split-Path $driver.InfPath -Leaf
        $driverPath = Split-Path $driver.InfPath -Parent
    }

    [PSCustomObject]@{
        PrinterName = $printer.Name
        PortName    = $printer.PortName
        PrinterIP   = $port.PrinterHostAddress
        DriverName  = $printer.DriverName
        INFFile     = $infFile
        DriverPath  = $driverPath
    } | Format-List

    $command = ("-PortName `"{0}`" -PrinterIP `"{1}`" -PrinterName `"{2}`" -DriverName `"{3}`" -INFFile `"{4}`"" -f `
        $printer.PortName, $port.PrinterHostAddress, $printer.Name, $printer.DriverName, $infFile)

    Write-Host "Ready-to-use command:" -ForegroundColor Cyan
    Write-Host $command

    $safeName     = Get-SafeFileName -Name $printer.Name
    $printerFolder = Join-Path $OutputPath $safeName

    if (-not (Test-Path $printerFolder)) {
        New-Item -ItemType Directory -Path $printerFolder -Force | Out-Null
    }

    $command | Out-File -FilePath (Join-Path $printerFolder "$safeName.txt") -Encoding ascii

    if ($driverPath -and (Test-Path $driverPath)) {
        Write-Host "Copying driver files from $driverPath to $printerFolder ..." -ForegroundColor Cyan
        Copy-Item -Path (Join-Path $driverPath '*') -Destination $printerFolder -Recurse -Force
    } else {
        Write-Host "Driver path not found - driver may not be in the DriverStore, or InfPath wasn't reported. No files copied." -ForegroundColor Yellow
    }

    Write-Host "Package folder: $printerFolder" -ForegroundColor Green
    Write-Host ("-" * 100)
}
