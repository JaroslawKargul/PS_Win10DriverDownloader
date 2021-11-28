. "$PSScriptRoot`\functions.ps1"

########################
# Create log directory #
########################

Start-LogFile "$ENV:PROGRAMDATA`\Hemmersbach\OSD\USB_DriverDownloader\5_Uipp_UnpackToUSB.log"

# Import reference table
. "$PSScriptRoot`\hp_reference.ps1"

# Get chosen model ID
$ID_Model = Get-Content "$PSScriptRoot`\modelchoice.txt"
$ChosenModelData = $GLOBAL:HP_Reference[[int]$($ID_Model.Trim())]

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

$URLFileName = Get-URLFileName -URI $ChosenModelData.URL
$CVAFileName = Get-URLFileName -URI $ChosenModelData.CVAURL

# Check CVA file if there are any instructions on how to unpack our downloaded driver package

# Get USB drive
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

$USBDriverDir = "$USBDrive`:\SMS\DRIVERS"
if (-not (Test-Path $USBDriverDir)){
    New-Item $USBDriverDir -ItemType directory | out-null
}
else{
    Remove-Item "$USBDriverDir`\*" -Recurse -Force
}

$FolderName = $URLFileName.Split(".")[0]
$USBSoftPaqPath = "$USBDriverDir`\$FolderName"

$tempSoftPaqEXEPath = "$PSScriptRoot`\HPSoftPaqDownloadData`\$URLFileName"

$7Zip = "$PSScriptRoot`\7z\7za.exe"

if (-not (Test-Path $tempSoftPaqEXEPath)){
    Add-LogEntry "(!)Driver not found in path: `"$tempSoftPaqEXEPath`"!"
    Finish-Log 4
    exit 4
}

Add-LogEntry "Unpacking the downloaded driver to USB (`"$tempSoftPaqEXEPath`" -> `"$USBSoftPaqPath`")..."

# Do not kick out to lockscreen... Gotta love this workaround I have to do!
Start-Process powershell -WindowStyle Hidden -ArgumentList "-executionpolicy bypass", "-file `"$PSScriptRoot`\no_monitor_timeout.ps1`""

try{
    $7zProcess = Start-Process -FilePath $7Zip -ArgumentList "x", "`"$tempSoftPaqEXEPath`"", "-o`"$USBSoftPaqPath`"" -PassThru -Wait -WindowStyle Hidden
}
catch{
    Add-LogEntry "(!)7-Zip unpacking failed! Error: $(($PSItem | Out-String).Trim())"

    # Inform no_monitor_timeout.ps1
    New-Item "$PSScriptRoot`\unpack_finished.txt" -ItemType file | out-null
    Start-Sleep 2

    Finish-Log 5
    exit 5
}

# Inform no_monitor_timeout.ps1
New-Item "$PSScriptRoot`\unpack_finished.txt" -ItemType file | out-null
Start-Sleep 2

# Check if CVA file exists in main directory...
if (Test-Path $USBSoftPaqPath){
    $CVAPresent = Get-ChildItem -Path $USBSoftPaqPath -Filter *.cva
    $ReadmePresent = Get-ChildItem -Path $USBDriverDir -Filter readme.txt -Recurse
}
else{
    # USB driver directory not found!
    Add-LogEntry "(!)USB driver directory not found!"
    Finish-Log 9
    exit 9
}

if (-not $CVAPresent -or -not $ReadmePresent){
    Add-LogEntry "(!)CVA or readme.txt file not present! Showing message to user..."
    Finish-Log 99
    exit 99
}
else{
    # If everything is in place, leave easily parsable driver data file on the USB stick
    Add-LogEntry "Trying to save powershell driver info in main USB driver directory ($USBDriverDir)..."

    if ($ReadmePresent.GetType().Name -ne "FileInfo"){
        $ReadmePresent = $ReadmePresent[0]
    }

    # Parse readme.txt...
    $Platforms_Supported = @(
        "Platforms Supported:"
        "Platforms Supported"
        "Supported Platforms:"
        "Supported Platforms"
    )

    $HP_Model_To_WMI_Cutoff = @{
        " Notebook PC" = ""
        " Small Form Factor PC" = " SFF"
        " Microtower PC" = " MT"
        " Business PC" = ""
    }

    $SupportedReadmeModelsArray = @()
    $SupportedReadmeModels = ""
    $start_gathering_models = $false

    foreach ($line in $(Get-Content $ReadmePresent.FullName)){
        if ($line.Trim() -in $Platforms_Supported){
            $start_gathering_models = $true
            continue
        }

        if (Get-IsStringEmpty $($line.Trim())){
            $start_gathering_models = $false
            continue
        }

        if ($start_gathering_models){
            $SupportedReadmeModelsArray += $line.Trim()

            $HP_Model_To_WMI_Cutoff.GetEnumerator() |% {
                if ($line.Trim() -like "*$($_.Key)"){
                    $altered_line = $line.Trim() -replace($($_.Key), $($_.Value))

                    if ($altered_line -notin $SupportedReadmeModelsArray){
                        $SupportedReadmeModelsArray += $altered_line.Trim()
                    }
                }
            }
        }
    }

    # In some cases, the CVA file has unexpected data format.
    # Check if model written in the driver list is present on our supported list, just in case.
    $DList_Model = $($ChosenModelData.Model).Trim()
    if ($DList_Model -notin $SupportedReadmeModelsArray){
        $SupportedReadmeModelsArray += $DList_Model

        $HP_Model_To_WMI_Cutoff.GetEnumerator() |% {
            if ($DList_Model -like "*$($_.Key)"){
                $altered_line = $DList_Model -replace($($_.Key), $($_.Value))

                if ($altered_line -notin $SupportedReadmeModelsArray){
                    $SupportedReadmeModelsArray += $altered_line.Trim()
                }
            }
        }
    }

    foreach ($str_model in $SupportedReadmeModelsArray){
        $SupportedReadmeModels += "    `"$str_model`"`n"
    }

    $USB_DriverDataString = "`$GLOBAL:DriverData = @{
`"Model`" = `"$($ChosenModelData.Model)`"
`"SpFileName`" = `"$URLFileName`"
`"CvaFileName`" = `"$CVAFileName`"
`"SpURL`" = `"$($ChosenModelData.URL)`"
`"OriginalSize`" = `"$($ChosenModelData.Size)`"
`"SystemBoardId`" = `"$($ChosenModelData.SystemBoardId)`"
`"SupportedModels`" = `@(`n$SupportedReadmeModels  )
# NOTE: If set to `$true, this will skip the system board / model verification step when installing drivers
`"ForceInstall`" = `$false
}"
    try{
        $USB_DriverDataString | out-file "$USBDriverDir`\HPdriverdata.ps1" -Force
    }
    catch{
        Add-LogEntry "(!)Failed saving powershell info! Error: $(($PSItem | Out-String).Trim())"
        Finish-Log 999
        exit 999
    }

    Finish-Log 0
    exit 0
}
