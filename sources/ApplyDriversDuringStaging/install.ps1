#################
##- FUNCTIONS -##
#################

. "$PSScriptRoot`\functions.ps1"
. "$PSScriptRoot`\bcu_parser_module.ps1"

function Get-TSOSDisk(){
    Add-LogEntry "Checking current OS Drive letter..."

    $OSDisk = (Get-Disk |? { $_.BusType -ne "USB" } | Get-Partition |? { $_.Type -eq "Basic" -and -not (Get-IsStringEmpty "$($_.DriveLetter)") } | Get-Volume |? { $_.DriveType -eq "Fixed" -and $_.FileSystemLabel -eq "Windows" }).DriveLetter

    if (Get-IsStringEmpty "$($OSDisk)"){
        Add-LogEntry "(!)DriveLetter of found OS Drive is empty! Error finding OS drive!"
        Finish-Log 7
        Copy-Item $LogPath -Destination "$USBDriverDir`\LastDrvInstall.log" -Force
        exit 0
    }
    else{
        Add-LogEntry "Found OS Drive with DriveLetter: $OSDisk"
    }

    return "$OSDisk`:"
}

function Import-DriversToImage($OSDisk, $USBDriverDir){
    Add-LogEntry "Running commandline: `"DISM /Image:$OSDisk\ /Add-Driver /Driver:$USBDriverDir\ /Recurse`""

    $DismOutput = Run-CMDAndGetOutput "DISM /Image:$OSDisk\ /Add-Driver /Driver:$USBDriverDir\ /Recurse"
    $DismOutputParsed = $DismOutput -split("[.]\s+") | Out-String

    Add-LogEntry "DISM Output:"
    Add-LogEntry $DismOutputParsed

    if ($DismOutputParsed -like "*The operation completed successfully.*"){
        Add-LogEntry "Successfully applied drivers. Setting TSvar `"HEM_AppliedDriversFromUSB`"..."

        try{
            $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
            $tsenv.Value('HEM_AppliedDriversFromUSB') = $true
            $HEM_AppliedDriversFromUSB = $tsenv.Value('HEM_AppliedDriversFromUSB')
        }
        catch{
            Add-LogEntry "(!)Failed to access TS Environment or set TSvar!"
            Add-LogEntry "(!)$(($PSItem | Out-String).Trim())"
        }

        if ($HEM_AppliedDriversFromUSB -eq $true -or $HEM_AppliedDriversFromUSB -eq "True"){
            Add-LogEntry "TSvar set successfully."
        }
    }
}

############
##- MAIN -##
############

$LogPath = "X:\sms\bin\x64\LastDrvInstall.log"
Start-LogFile $LogPath

# Get USB drive
$USB = $(get-disk | where BusType -eq USB | get-partition | get-volume)
$USBDrive = $USB.DriveLetter |? {
    Test-Path "$_`:\SMS\PKG"
}

# No USB found
if (-not $USBDrive){
    Add-LogEntry "(!)USB stick with Win10 v1909 could not be found!"
    Finish-Log 3
    exit 0
}
else{
    Add-LogEntry "OK - USB stick with Win10 v1909 found. Assigned driveletter: $USBDrive"
}

$USBDriverDir = "$USBDrive`:\SMS\DRIVERS"
$PSDriverData = "$USBDriverDir`\HPdriverdata.ps1"

Add-LogEntry "Driver directory resolved to: `"$USBDriverDir`"."
Add-LogEntry "Checking if directory exists..."

if (Test-Path $PSDriverData){
    Add-LogEntry "Driver data directory and PS1 file exist."

    . $PSDriverData

    if (-not $GLOBAL:DriverData){
        Add-LogEntry "(!)Failed to load driver data from PS1 file!"
        Finish-Log 4
        Copy-Item $LogPath -Destination "$USBDriverDir`\LastDrvInstall.log" -Force
        exit 0
    }

    $OSDisk = Get-TSOSDisk

    Add-MainLogEntry "SYSTEM BOARD ID CHECK"

    $SystemBoardIdUSB = $GLOBAL:DriverData.SystemBoardId
    Add-LogEntry "System Board ID in the PS1 file: $SystemBoardIdUSB"

    Add-LogEntry "Attempting to extract HP BIOS Settings..."
    $HPBIOSSettings = Get-BiosSettings

    $SystemBoardIdComp = foreach ($setting in $HPBIOSSettings){
        $setting.GetEnumerator() |? {
            $_.Key -like "System Board ID*"
        }
    }

    if ($SystemBoardIdUSB -eq $SystemBoardIdComp.Value){
        Add-LogEntry "System Board ID value in BIOS Settings: $($SystemBoardIdComp.Value)"
        Add-LogEntry "$($SystemBoardIdComp.Value) == $SystemBoardIdUSB"

        Import-DriversToImage $OSDisk $USBDriverDir
    }
    else{
        Add-LogEntry "System Board ID value in BIOS Settings: $($SystemBoardIdComp.Value)"
        Add-LogEntry "$($SystemBoardIdComp.Value) != $SystemBoardIdUSB"

        if ($SystemBoardIdComp.Value -like "*,*"){
            Add-LogEntry "System Board ID contains a comma (`",`"). This could mean that this Board has multiple IDs."
            Add-LogEntry "Checking every possible ID..."

            $BoardIDs = $SystemBoardIdComp.Value.split(",")
            foreach ($BID in $BoardIDs){
                if ($BID -ne $SystemBoardIdUSB){
                    Add-LogEntry "$BID != $SystemBoardIdUSB"
                }
                else{
                    Add-LogEntry "$BID == $SystemBoardIdUSB"
                    Import-DriversToImage $OSDrive $OSDriverDir

                    Finish-Log 7
                    exit 0
                }
            }
        }

        Add-MainLogEntry "MODEL NAME CHECK"

        $CurrentModel = $((Get-WmiObject -Class:Win32_ComputerSystem).Model).Trim()
        Add-LogEntry "Current machine model: $CurrentModel"
        Add-LogEntry "Checking if current driver pack on USB supports this model..."

        if ($CurrentModel -in $GLOBAL:DriverData.Model -or $CurrentModel -in $GLOBAL:DriverData.SupportedModels){
            Add-LogEntry "Current machine model is supported."
            Import-DriversToImage $OSDisk $USBDriverDir
        }
        else{
            Add-LogEntry "(!)Current model is not supported!"
            Add-LogEntry "Checking if driver installation is forced..."
            if ($GLOBAL:DriverData.ForceInstall){
                Add-LogEntry "Driver installation is forced."
                Import-DriversToImage $OSDisk $USBDriverDir
            }
            else{
                Add-LogEntry "(!)Driver installation is NOT forced. Skipping..."
                Finish-Log 9
                Copy-Item $LogPath -Destination "$USBDriverDir`\LastDrvInstall.log" -Force
                exit 0
            }
        }

        Finish-Log 8
        Copy-Item $LogPath -Destination "$USBDriverDir`\LastDrvInstall.log" -Force
        exit 0
    }
}
else{
    # No drivers found. We don't need to report this fact. Simply skip everything.
    Finish-Log 0
    exit 0
}

Finish-Log 0
Copy-Item $LogPath -Destination "$USBDriverDir`\LastDrvInstall.log" -Force
exit 0
