# EXITCODES:
# 2: Temp folder creation failed
# 3: Temp file creation failed
# 4: Web request failed
# 5: Extracting driver data failed
# 6: Importing driver data failed
# 7: Generating driver list failed
# 8: Generating driver script failed

. "$PSScriptRoot`\functions.ps1"

function Ignore-SSLCertificate(){
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

########################
# Create log directory #
########################

Start-LogFile "$ENV:PROGRAMDATA`\Hemmersbach\OSD\USB_DriverDownloader\1_Uipp_DownloadHPDriverData.log"

### MAIN ###

$UIpp_XML_Start = '<?xml version="1.0" encoding="utf-8"?>
<UIpp Title="Hemmersbach IT" Icon="UI++2.ico" Color="#db6b0f">
<Actions>'

$UIpp_SettingStart = '	<Action Type="Input" Name="ModelChoice" Title=" Choose HP Device Model">
		<InputChoice Variable="HPModelChoice" Sort="True" Question="Please select the model of target computer." Required="True" AutoComplete="False">'

$UIpp_SettingOption = '			<Choice Option="!OPTIONNAME!" Value="!URL!"/>'

$UIpp_SettingEnd = '		</InputChoice>
	</Action>
	<Action Type="ExternalCall" ExitCodeVariable="INT_ExportChoice" Title="Saving choice...">PowerShell.exe -ExecutionPolicy ByPass -File "2_Uipp_ExportUserChoice.ps1" -Choice "%HPModelChoice%"</Action>'

$UIpp_XML_End = '</Actions>
</UIpp>'

Add-MainLogEntry "DIRECTORY PREPARATION & LIST DOWNLOAD"

$HPXMLCabinetSource = "http://ftp.hp.com/pub/caps-softpaq/cmit/HPClientDriverPackCatalog.cab"
$TemporaryDataFolder = "$PSScriptRoot`\HPSoftPaqDownloadData"
$CABFileName = [string]($HPXMLCabinetSource | Split-Path -Leaf)
$XMLFileName = "HPData.xml"

if (Test-Path $TemporaryDataFolder){
    Add-LogEntry "(!)Old temporary data folder found! Trying to delete it..."
    Remove-Item $TemporaryDataFolder -Recurse -Force | out-null
}
else{
    Add-LogEntry "No old temporary data folder found."
}

if (-not $(Test-Path $TemporaryDataFolder)){
    Add-LogEntry "Could not find folder `"$TemporaryDataFolder`". Trying to create..."

    try{
        New-Item $TemporaryDataFolder -Force -ItemType directory -ErrorAction Stop
    }
    catch{
        Add-LogEntry "(!)Failed creating folder with error: $(($PSItem | Out-String).Trim())"
        Finish-Log 2
        exit 2
    }
    
    Add-LogEntry "Trying to create temporary CAB file named `"$CABFileName`"..."
    try{
        New-Item "$TemporaryDataFolder`\$CABFileName" -Force -ItemType file -ErrorAction Stop
    }
    catch{
        Add-LogEntry "(!)Failed creating file with error: $(($PSItem | Out-String).Trim())"
        Finish-Log 3
        exit 3
    }
}

Start-Sleep 1

Add-LogEntry "Requesting the CAB file (containing driver list) from the HP website..."

try{
    Invoke-WebRequest -Uri $HPXMLCabinetSource -OutFile "$TemporaryDataFolder`\$CABFileName" -TimeoutSec 120
}
catch{
    if ($(($PSItem | Out-String).Trim()) -like "*Could not establish trust relationship*"){
        Add-LogEntry "(!)SSL Certificate error! Trying to ignore it and retrying..."

        Ignore-SSLCertificate

        try{
            Invoke-WebRequest -Uri $HPXMLCabinetSource -OutFile "$TemporaryDataFolder`\$CABFileName" -TimeoutSec 120
        }
        catch{
            Add-LogEntry "(!)Invoke-WebRequest failed with error: $(($PSItem | Out-String).Trim())"
            Finish-Log 4
            exit 4
        }
    }
    else{
        Add-LogEntry "(!)Invoke-WebRequest failed with error: $(($PSItem | Out-String).Trim())"
        Finish-Log 4
        exit 4
    }
}

# Unpack the CAB file
Add-LogEntry "Unpacking the CAB file (`"$TemporaryDataFolder`\$CABFileName`" -> `"$TemporaryDataFolder`\$XMLFileName`")"

if (Test-Path "$ENV:SYSTEMROOT`\System32\expand.exe"){
     $EXPAND_EXE = "$ENV:SYSTEMROOT`\System32\expand.exe"
}
else{
    Add-LogEntry "(!)Native `"expand.exe`" not found. Our own version will be used."
    $EXPAND_EXE = "$PSScriptRoot`\expand.exe"
}

try{
    Start-Process $EXPAND_EXE -ArgumentList "$TemporaryDataFolder`\$CABFileName", "$TemporaryDataFolder`\$XMLFileName" -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
}
catch{
    Add-LogEntry "(!)Expand.exe failed with error: $(($PSItem | Out-String).Trim())"
    Finish-Log 5
    exit 5
}


Add-LogEntry "Importing the unpacked XML file into PowerShell..."

try{
    [xml]$XMLFile = get-content "$TemporaryDataFolder`\$XMLFileName" -ErrorAction Stop
}
catch{
    Add-LogEntry "(!)Importing XML failed with error: $(($PSItem | Out-String).Trim())"
    Finish-Log 6
    exit 6
}

$HPModelList = [pscustomobject]@()

# Id, Name, Version, Category, DateReleased, Url, Size, MD5, SHA256, CvaFileUrl, ReleaseNotesUrl, CvaTitle
$SoftPaqs = $XMLFile.NewDataSet.HPClientDriverPackCatalog.SoftPaqList.SoftPaq

# Architecture, ProductType, SystemId, SystemName, OSName, OSId, SoftPaqId, ProductId
$List = $XMLFile.NewDataSet.HPClientDriverPackCatalog.ProductOSDriverPackList.ProductOSDriverPack

if (-not $SoftPaqs -or -not $List){
    Add-LogEntry "(!)Exported SoftPaq or Model list was empty! ...Has HP updated the XML?"
    Finish-Log 999
    exit 999
}

# Get only newest driver that is equal to 1909 or older than that.
Add-MainLogEntry "FILTER DRIVERS"

$FilteredList = [pscustomobject]@()
$tempModels = [pscustomobject]@()

Add-LogEntry "Creating a list of models (no duplicate entries)..."
foreach ($Model in $List.SystemName){
    if ($Model -notin $tempModels){
        $tempModels += $Model
    }
}

Add-LogEntry "Creating a filtered list of models (up to Win10 v1909 allowed, get only newest driver for each model)..."
foreach ($tempModel in $tempModels){
    $AllDriversForThisModel = $List |? { $_.SystemName -eq $tempModel }
    #Add-LogEntry "Number of available drivers for model `"$tempModel`"`: $($AllDriversForThisModel.Count)"

    if ($AllDriversForThisModel.GetType().Name -ne "XMLElement" -and $AllDriversForThisModel.Count -gt 1){
        $Drv = $AllDriversForThisModel |? { 
            $_.OSName -like "Windows 10 64-bit*" #-and
            #$_.OSName -le "Windows 10 64-bit, 1909"
        }

        #Add-LogEntry "After filtering there is following number of drivers: $($Drv.Count)"
        #Add-LogEntry "Remaining driver versions: $(($Drv.OSName | Out-String).Trim())"

        $DriverAvailable = $Drv | Sort-Object -Property OSName | Select-Object -Last 1

        #Add-LogEntry "Filtered out newest driver (compatible with Win10 v1909): $($DriverAvailable.SoftPaqId), OS Ver: $($DriverAvailable.OSName)"
        #Add-LogEntry ""

        $FilteredList += $DriverAvailable
    }
    elseif ($AllDriversForThisModel.GetType().Name -eq "XMLElement"){
        $FilteredList += $AllDriversForThisModel
    }
}

# Create a list

Add-LogEntry "Creating an object list for further UI++ and PowerShell actions..."
foreach ($MachineData in $FilteredList){
    if (-not ([string]::IsNullOrEmpty($MachineData.SystemName)) -and
        $MachineData.SystemName -notin $HPModelList){

            $ShorterName = "$($MachineData.SystemName)"
            if ($ShorterName.Length -gt 45){
                $ShorterName = "$($ShorterName.substring(0, [System.Math]::Min(45, $ShorterName.Length)))..."
            }
            
            $Sp = $SoftPaqs |? { $_.Id -eq $MachineData.SoftPaqId }
            $SpUrl = "$($Sp.URL)"
            $SpCvaUrl = "$($Sp.CvaFileUrl)"
            $SpSize = "$($Sp.Size)"

            if ([string]::IsNullOrEmpty($SpSize)){
                $SpSize = "???"
            }

            if (-not ([string]::IsNullOrEmpty($SpUrl)) -and -not ([string]::IsNullOrEmpty($SpCvaUrl))){
                $HPModelList += [pscustomobject]@{
                    OptionName = $ShorterName
                    SystemName = $MachineData.SystemName
                    URL = $SpUrl
                    CVAURL = $SpCvaUrl
                    DrvSize = "$([math]::round($($SpSize / 1Mb), 0))MB"
                    SystemId = $MachineData.SystemId
                }
            }
    }
}

$HPModelList = $HPModelList | Sort-Object -Property OptionName

# Build UI++ configuration file
Add-LogEntry "Building UI++ config file..."
$temp_AllSettings = ""
$nr = 1
$HPModelList |% {
    $temp_AllSettings += "$($UIpp_SettingOption.Replace("!OPTIONNAME!", $_.OptionName))`n".Replace("!URL!", "$nr")
    $nr++
}

$FinalFile = "$UIpp_XML_Start
$UIpp_SettingStart
$($temp_AllSettings.TrimEnd())
$UIpp_SettingEnd
$UIpp_XML_End
"

Add-LogEntry "Saving UI++ config file in: `"$PSScriptRoot`\UI++2.xml`""
try{
    $FinalFile | out-file "$PSScriptRoot`\UI++2.xml" -Force -ErrorAction Stop
}
catch{
    Add-LogEntry "(!)Saving UI++ config failed with error: $(($PSItem | Out-String).Trim())"
    Finish-Log 7
    exit 7
}

# Build reference file...
Add-LogEntry "Building PS1 reference data file..."
$ReferenceFileData = "`$GLOBAL:HP_Reference = @{`n"
$nr = 1
$HPModelList |% {
    $ReferenceFileData += "$nr = @{ URL=`"$($_.URL)`"; CVAURL=`"$($_.CVAURL)`"; Model=`"$($_.SystemName)`"; SystemBoardId = `"$($_.SystemId)`"; Size = `"$($_.DrvSize)`" }`n"
    $nr++
}
$ReferenceFileData = "$ReferenceFileData}"

Add-LogEntry "Saving PS1 reference data file in: `"$PSScriptRoot`\hp_reference.ps1`""
try{
    $ReferenceFileData | out-file "$PSScriptRoot`\hp_reference.ps1" -Force -ErrorAction Stop
}
catch{
    Add-LogEntry "(!)Saving PS1 file failed with error: $(($PSItem | Out-String).Trim())"
    Finish-Log 8
    exit 8
}

Finish-Log 0
exit 0
