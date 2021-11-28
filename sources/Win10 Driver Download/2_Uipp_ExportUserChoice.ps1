param($Choice)

. "$PSScriptRoot`\functions.ps1"

########################
# Create log directory #
########################

Start-LogFile "$ENV:PROGRAMDATA`\Hemmersbach\OSD\USB_DriverDownloader\2_Uipp_ExportUserChoice.log"
Add-LogEntry "Script started with following argument: `$Choice = $Choice"

Add-LogEntry "Trying to create empty model choice file (`"$PSScriptRoot`\modelchoice.txt`")..."
try{
    New-Item "$PSScriptRoot`\modelchoice.txt" -ItemType file -ErrorAction Stop 
}
catch{
    Add-LogEntry "(!)Failed to create empty file! Error: $(($PSItem | Out-String).Trim())"
    Finish-Log 2
    exit 2
}

Add-LogEntry "Trying to save data to file using Set-Content cmdlet..."
try{
    Set-Content "$PSScriptRoot`\modelchoice.txt" -Value $Choice -Force -ErrorAction Stop
}
catch{
    Add-LogEntry "(!)Failed to save data to file! Error: $(($PSItem | Out-String).Trim())"
    Finish-Log 3
    exit 3
}

Finish-Log 0
exit 0