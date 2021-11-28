. "$PSScriptRoot`\functions.ps1"

########################
# Create log directory #
########################

Start-LogFile "$ENV:PROGRAMDATA`\Hemmersbach\OSD\USB_DriverDownloader\0_Uipp_StartVerification.log"

#################################################
# Get Windows version - only Win10 is supported #
#################################################

Add-MainLogEntry "WINDOWS VERSION CHECK"
$OSWinVer = (Get-CimInstance Win32_OperatingSystem).Version
if ("$OSWinVer" -notlike "*10.0*"){
    Add-LogEntry "(!)Detected target machine Windows version: $OSWinVer"
    Add-LogEntry "(!)Script cannot continue!"
    Finish-Log 7
    exit 7
}
else{
    Add-LogEntry "Windows version is supported ($OSWinVer), continuing..."
}

#################
# Get USB drive #
#################

Add-MainLogEntry "USB DRIVE CHECK"

$USB = $(get-disk | where BusType -eq USB | get-partition | get-volume)
$USBDrive = $USB.DriveLetter |? {
    Test-Path "$_`:\SMS\PKG"
}

# No USB found
if (-not $USBDrive){
    Add-LogEntry "(!)USB stick with Win10 v1909 could not be found!"
    Finish-Log 3
    exit 3
}
else{
    Add-LogEntry "OK - USB stick with Win10 v1909 found. Assigned driveletter: $USBDrive"
}

###########################
# Free space verification #
###########################

Add-MainLogEntry "FREE SPACE CHECK"

# This gets drive based off current working directory - but since 7-Zip self-extracting archive always caches in TEMP,
# We can simply assume, that current directory will always be on the drive with Operating System.
$LocalDisk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$((Get-Location).Drive.Name):'" | Select-Object Size,FreeSpace

if ($LocalDisk.FreeSpace -lt 2GB){
    Add-LogEntry "(!)There is less than 2GB free space on local drive ($((Get-Location).Drive.Name)`:)! Free space: $([math]::round($($LocalDisk.FreeSpace / 1Gb), 2))GB"
    Finish-Log 4
    exit 4
}
else{
    Add-LogEntry "OK - There is at least 2GB free space on local drive ($((Get-Location).Drive.Name)`:). Free space: $([math]::round($($LocalDisk.FreeSpace / 1Gb), 2))GB"
}

$USBDiskSpace = (Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$USBDrive`:'" | Select-Object FreeSpace).FreeSpace
if (-not $USBDiskSpace -or $USBDiskSpace -lt 2GB){
    Add-LogEntry "(!)There is less than 2GB free space on USB drive! Free space: $([math]::round($($USBDiskSpace / 1Gb), 2))GB"
    Finish-Log 5
    exit 5
}
else{
    Add-LogEntry "OK - There is at least 2GB free space on USB drive. Free space: $([math]::round($($USBDiskSpace / 1Gb), 2))GB"
}

##################
# Internet check #
##################

$PingGoogle = Test-Connection "google.com" -Count 2 -ErrorAction SilentlyContinue
$PingHem = Test-Connection "hemmersbach.com" -Count 2 -ErrorAction SilentlyContinue

if ($PingGoogle -or $PingHem){
    Add-LogEntry "OK - Test-Connection confirmed that we're connected to Internet (pinged `"google.com`" or `"hemmersbach.com`")."
}
else {
    Add-LogEntry "(!)Internet connection not established! Cannot ping `"google.com`" and `"hemmersbach.com`"!"
    Finish-Log 6
    exit 6
}

Finish-Log 0
exit 0