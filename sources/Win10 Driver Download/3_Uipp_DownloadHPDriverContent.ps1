. "$PSScriptRoot`\functions.ps1"

########################
# Create log directory #
########################

Start-LogFile "$ENV:PROGRAMDATA`\Hemmersbach\OSD\USB_DriverDownloader\3_Uipp_DownloadHPDriverContent.log"

# Import reference table
. "$PSScriptRoot`\hp_reference.ps1"

# Get chosen model ID
Add-MainLogEntry "DATA IMPORT"
Add-LogEntry "Trying to import data file `"$PSScriptRoot`\modelchoice.txt`"..."
try{
    $ID_Model = Get-Content "$PSScriptRoot`\modelchoice.txt"
}
catch{
    Add-LogEntry "(!)Failed to import data! Error: $(($PSItem | Out-String).Trim())"
    Finish-Log 1
    exit 1
}
$ChosenModelData = $GLOBAL:HP_Reference[[int]$($ID_Model.Trim())]

Add-LogEntry "Resolving model data -> Chosen model is: `"$($ChosenModelData.Model)`""


# WAIT! Do we even have enough disk space to do this?
$LocalDisk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$((Get-Location).Drive.Name):'" | Select-Object Size,FreeSpace

if ($LocalDisk.FreeSpace -lt $ChosenModelData.Size){
    Add-LogEntry "(!)There is less free space than required size ($($ChosenModelData.Size)) on local drive ($((Get-Location).Drive.Name)`:)! Free space: $([math]::round($($LocalDisk.FreeSpace / 1Gb), 2))GB"
    Finish-Log 99
    exit 99
}
else{
    Add-LogEntry "OK - There is enough free space on local drive ($((Get-Location).Drive.Name)`:). Required:$($ChosenModelData.Size); Free space:$([math]::round($($LocalDisk.FreeSpace / 1Gb), 2))GB"
}

# CHECK USB AS WELL. The size should be at least x2.5 bigger there (I tested this, in some cases the driver grows like crazy when unpacked).
$USBSpaceRequired = [math]::round($((($ChosenModelData.Size / 2)*5) / 1Mb), 2)

# Get only the partition where driveletter is not empty.
$USBDriveLetter = (Get-Disk |? { $_.BusType -eq "USB" } | Get-Partition).DriveLetter
$USBDriveLetter = $USBDriveLetter |? {
    Test-Path "$_`:\SMS\PKG"
}

$USBDiskSpace = (Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$USBDriveLetter`:'" | Select-Object FreeSpace).FreeSpace
if (-not $USBDiskSpace -or $USBDiskSpace -lt $USBSpaceRequired){
    Add-LogEntry "(!)There is less free space than required size ($USBSpaceRequired) on USB! Free space: $([math]::round($($USBDiskSpace / 1Gb), 2))GB"
    Finish-Log 999
    exit 999
}
else{
    Add-LogEntry "OK - There is enough free space on USB drive. Required:$USBSpaceRequired`MB; Free space:$([math]::round($($USBDiskSpace / 1Gb), 2))GB"
}


function Get-URLFileName ($URI)
{
	$RequestPage = [System.Net.HttpWebRequest]::Create($URI)
	$RequestPage.Method = "HEAD"
	$Response = $RequestPage.GetResponse()
	$FullURL = $Response.ResponseUri
	$FileName = [System.IO.Path]::GetFileName($FullURL.LocalPath);
	$Response.Close()
			
	return $FileName
}

# You can believe it or not, but this actually speeds up the download...
$ProgressPreference = 'SilentlyContinue'

# Calculate file size during download
$URLFileName = Get-URLFileName -URI $ChosenModelData.URL
$FullSize = $ChosenModelData.Size

Add-MainLogEntry "PROGRESS BAR"

# WindowStyle must be declared BEFORE the file to work properly
# (?) TODO: .NET FRAMEWORK CHECK SHOULD BE HERE ???
Add-LogEntry "Starting progress bar - full driver file size is: $FullSize"
Start-Process powershell -WindowStyle Hidden -ArgumentList "-executionpolicy bypass", "-file `"$PSScriptRoot`\4_Uipp_ProgressBar.ps1`"", "-URLFileName $URLFileName", "-FullSize $FullSize"

# Download the driver
Add-MainLogEntry "DRIVER DOWNLOAD"
Add-LogEntry "Downloading the driver ($URLFileName)..."
try{
    Invoke-WebRequest -Uri $ChosenModelData.URL -OutFile "$PSScriptRoot`\HPSoftPaqDownloadData`\$URLFileName" -TimeoutSec 120
}
catch{
    if ($(($PSItem | Out-String).Trim()) -like "*Could not establish trust relationship*"){
        Add-LogEntry "(!)SSL Certificate error! Trying to ignore it and retrying..."

        Ignore-SSLCertificate

        try{
            Invoke-WebRequest -Uri $ChosenModelData.URL -OutFile "$PSScriptRoot`\HPSoftPaqDownloadData`\$URLFileName" -TimeoutSec 120
        }
        catch{
            Add-LogEntry "(!)Failed to download driver! Error: $(($PSItem | Out-String).Trim())"
            # Inform progress bar
            New-Item "$PSScriptRoot`\downloadfinished.txt" | out-null

            Finish-Log 2
            exit 2
        }
    }
    else{
        Add-LogEntry "(!)Failed to download driver! Error: $(($PSItem | Out-String).Trim())"
        # Inform progress bar
        New-Item "$PSScriptRoot`\downloadfinished.txt" | out-null

        Finish-Log 2
        exit 2
    }
}

<# Download the CVA file
$CVAFileName = Get-URLFileName -URI $ChosenModelData.CVAURL
try{
    Invoke-WebRequest -Uri $ChosenModelData.CVAURL -OutFile "$PSScriptRoot`\HPSoftPaqDownloadData`\$CVAFileName" -TimeoutSec 120 -ErrorAction Stop
}
catch{
    exit 3
}
#>

# Inform progress bar
Add-LogEntry "Creating progress bar finish trigger file..."
try{
    New-Item "$PSScriptRoot`\downloadfinished.txt"
}
catch{
    Add-LogEntry "(!)Failed to create file! Error: $(($PSItem | Out-String).Trim())"
    Finish-Log 4
    exit 4
}

Finish-Log 0
exit 0