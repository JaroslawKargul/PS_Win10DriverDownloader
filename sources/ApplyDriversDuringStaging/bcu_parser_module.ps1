<#
.NOTES
Module Name  : BCU Parser Module
Functions    : Get-BIOSSettings, Get-BIOSSettingValue, Set-BIOSSettings
Created by   : Jaroslaw Kargul
Date Coded   : 08/16/2020

.USAGE
Load this module as shown below:
. "$path_to_parser`\bcu_parser_module.ps1"
#>

$GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE = $null
$GLOBAL:BCUPARSER_CUSTOMIZED_BIOS_TABLE = $null
$GLOBAL:BCUPARSER_ITERATED_BIOS_TABLE = $null

$GLOBAL:BCUPARSER_FILEPATH = "$ENV:PROGRAMDATA`\BCU"
$GLOBAL:BCUPARSER_FILEPATH |% { if (-not (Test-Path $_)){ New-Item -ItemType Directory -Path $ENV:PROGRAMDATA -Name "BCU" | Out-Null }}
$GLOBAL:BCUPARSER_exportedCFGpath = "$GLOBAL:BCUPARSER_FILEPATH\$($ENV:COMPUTERNAME)_export.cfg"
$GLOBAL:BCUPARSER_customCFGpath = "$GLOBAL:BCUPARSER_FILEPATH\$($ENV:COMPUTERNAME)_custom.cfg"
$GLOBAL:BCUPARSER_BIOS_PWD_Path = "$GLOBAL:BCUPARSER_FILEPATH\$($ENV:COMPUTERNAME)_pwd.bin"
$GLOBAL:BCUPARSER_BCU_Path = "$PSSCRIPTROOT`\BCU\BCU.exe"
$GLOBAL:BCUPARSER_BCUPW_Path = "$PSSCRIPTROOT`\BCU\BCUPW.exe"

# All errorcodes described by HP
$GLOBAL:BCUPARSER_ErrorTable = @{
    1 = "Setting not supported on the system."
    2 = "Unknown error."
    3 = "Operation timed out."
    4 = "Operation failed."
    5 = "Invalid parameter."
    6 = "Access denied."
    10 = "Invalid password."
    11 = "Invalid config file."
    12 = "Error in config file."
    13 = "Failed to change one or more settings."
    14 = "Failed to write file."
    15 = "Syntax error."
    16 = "Unable to write to file/system."
    17 = "Failed to change settings."
    18 = "Unchanged setting."
    19 = "One of settings is read-only."
    20 = "Invalid setting name."
    21 = "Invalid setting value."
    23 = "Unsupported system."
    24 = "Unsupported system."
    25 = "Unsupported system."
    30 = "Password file error."
    31 = "Password not F10 compatible."
    32 = "Unsupported Unicode password."
    33 = "No settings found."
    35 = "Missing parameter."
    36 = "Missing parameter."
    37 = "Missing parameter."
    38 = "Corrupt or missing file."
    39 = "DLL file error."
    40 = "DLL file error."
    41 = "Invalid UID."
}
<#
.SYNTAX
Get-BIOSSettings

.DESCRIPTION
Returns all HP BIOS Settings in an object.
The returned object is an array with nested hashtables (where key = setting name, value = nested array which contains options of that setting).
#>

function Get-BIOSSettings(){

    # Delete old temp BIOS data files
    $GLOBAL:BCUPARSER_exportedCFGpath,
    $GLOBAL:BCUPARSER_customCFGpath,
    $GLOBAL:BCUPARSER_BIOS_PWD_Path |% { if (Test-Path $_){ Remove-Item -Path $_ -Force -ErrorAction SilentlyContinue | Out-Null } }

    # Extract setting from BIOS into a file
    $ExportCfgAttempt = Start-Process $GLOBAL:BCUPARSER_BCU_Path -ArgumentList "/Get:$GLOBAL:BCUPARSER_exportedCFGpath" -PassThru -WindowStyle Hidden -Wait

    # Check if we could export the settings
    if ($ExportCfgAttempt.ExitCode -ne 0)
    {
        Throw "Get-BIOSSettings : Failed to export BIOS settings with exitcode `"$($ExportCfgAttempt.ExitCode)`". BCU did not export a configuration file successfully.`nYou may be missing proper rights for this action."
        return
    }
    
    # Catch all settings into an object
    $all_configs = @()

    $temp_settingname = ""
    $temp_settings = @()

    $counter = 1

    foreach ($line in $(Get-Content $GLOBAL:BCUPARSER_exportedCFGpath -Encoding UTF8 | Select-Object -Skip 1)){
        if ($line -notlike "*;*" -and $line -notmatch "\t" -and $line -ne ""){
            # Beginning of a new setting
            if ([string]::IsNullOrEmpty($temp_settingname)){
                $temp_settingname = $line
            }
            elseif ($temp_settingname -ne $line){
                $all_configs += @{$temp_settingname = $temp_settings}
                $temp_settings = @()
                $temp_settingname = $line
            }
        }
        elseif ($line -notlike "*;*" -and $line -match "\t"){
            $temp_settings += $($line -replace "\t", "")
        }
    }

    $GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE = $all_configs
    return $all_configs
}

<#
.SYNTAX
Get-BIOSSettingValue [STRING]

.DESCRIPTION
Returns name of currently active option in specified BIOS setting:
- If search text does not containt asterisk (*): returns a [STRING],
- If search text contains asterisk (*): returns an [ARRAY] with nested hashtables (where key = setting name, value = active option).

.EXAMPLE
Get-BIOSSettingValue "Fingerprint Reader"
#>

function Get-BIOSSettingValue($SettingName){

    if (-not $SettingName){
        Throw "Get-BIOSSettingValue : Could not get BIOS setting value. No setting name has been provided."
        return
    }
    elseif ($SettingName.GetType().Name -ne 'String'){
        Throw "Get-BIOSSettingValue : Wrong data type. Provided setting name is not a string."
        return
    }
    
    #if (-not $GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE){
    $GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE = Get-BIOSSettings
    #}

    $temp_BIOS_setting_table = @()

    if ($SettingName -match "\*"){
        #Conduct a 'like' search if there is an asterisk in the string

        ForEach ($config in $GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()){
            if ($config.keys -like $SettingName){
                if ($config.values -match "\*"){
                    $temp_BIOS_setting_table += @{$($config.keys) = $($config.values |% {$_ -match "\*"})}
                }
                else{
                    $temp_BIOS_setting_table += @{$($config.keys) = $($config.values)[0]}
                }
            }
        }

        return $temp_BIOS_setting_table
    }
    else{
        if ($($GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()).$SettingName){
            if ($($GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()).$SettingName -match "\*"){
                return $($($($GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()).$SettingName) |? {$_ -match "\*"})
            }
            else{
                return $($($GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()).$SettingName)[0]
            }
        }
        else{
            Throw "Get-BIOSSettingValue : Requested value could not be found in BIOS settings. You can try including '*' in your string to broaden the search criteria."
            return
        }
    }
}

<#
.SYNTAX
Set-BIOSSettings [HASHTABLE] [STRING]

.DESCRIPTION
Saves declared BIOS settings. Hashtable must be formatted as shown below:
@{ $Setting_Name1 = $Setting_Value1; $Setting_Name2 = $Setting_Value2; ... }

.USAGE
Set-BIOSSettings @{'Microphone' = 'Disable'} 'p@55w0rd'
Above command sets "Microphone" BIOS setting to "Disable" using string "p@55w0rd" as BIOS password.

.REMARKS
The provided BIOS setting name must be exactly the same as in BIOS.
The BIOS setting value does not have to be exactly correct - it searches for a similar string.

.EXAMPLE
Set-BIOSSettings @{'Microphone' = 'Disab'} 'p@55w0rd'
The above command will set "Microphone" BIOS setting to "Disable".

.ERRORHANDLING
Errorhandling using this specific function can be done with try/catch, as shown below:
try { 
    Set-BIOSSettings @{'Bluetooth' = 'Dis'; 'USB Port' = 'e'} $password
} catch{
    $($PSItem.ToString())
}
Returned string will be:
"Set-BIOSSettings : Requested value string "e" for setting "USB Port" returned multiple correct results. Please be more specific with your request."
#>

function Set-BIOSSettings($InputObject, $Password){

    if (-not $InputObject){
        Throw "Set-BIOSSettings : Could not retrieve BIOS settings data. No input object was provided."
        return
    }
    elseif ($InputObject.GetType().Name -ne 'Hashtable'){
        Throw "Set-BIOSSettings : Could not retrieve BIOS settings data. Input object is not a hashtable."
        return
    }

    if ($Password -eq $null){
        Throw "Set-BIOSSettings : Password not provided. If the computer's BIOS has no set password, enter an empty string as password value."
        return
    }
    elseif ($Password.GetType().Name -ne 'String'){
        Throw "Set-BIOSSettings : Wrong data type. Provided password is not a string."
        return
    }
    
    if (Test-Path $GLOBAL:BCUPARSER_exportedCFGpath -ErrorAction SilentlyContinue){
        Remove-Item $GLOBAL:BCUPARSER_exportedCFGpath -Force -ErrorAction SilentlyContinue | Out-Null
    }

    if (Test-Path $GLOBAL:BCUPARSER_customCFGpath -ErrorAction SilentlyContinue){
        Remove-Item $GLOBAL:BCUPARSER_customCFGpath -Force -ErrorAction SilentlyContinue | Out-Null
    }

    #if (-not $GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE){
    $GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE = Get-BIOSSettings
    #}

    # Clear iterated BIOS table and number of results
    $GLOBAL:BCUPARSER_ITERATED_BIOS_TABLE = $null
    $GLOBAL:BCUPARSER_NR_RESULTS = 0

    ForEach ($Setting_Pair in $($InputObject.GetEnumerator())){
        $SettingName = $Setting_Pair.key
        $SettingValue = $Setting_Pair.value

        if ($($GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()).$SettingName){
            $temp_settings = @()

            if ($($GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()).$SettingName -match "\*"){

                $($($GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()).$SettingName) |% {
                    if ($_ -match "\*" -and -not $($_ -like "*$SettingValue*")){
                        $temp_settings += $_.replace('*', '')
                    }
                    elseif ($_ -notmatch "\*" -and $_ -like "*$SettingValue*"){
                        $temp_settings += "`*$_"
                    }
                    else{
                        $temp_settings += $_
                    }
                }
            }
            else{
                # First, search for the setting which needs to be on the top and put it in a table.
                # Then, get the rest of settings and put them into the table.

                $($($GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()).$SettingName) |% {
                    if ($_ -like "*$SettingValue*"){
                        $temp_settings += $_
                        $GLOBAL:BCUPARSER_NR_RESULTS++
                    }
                }

                $($($GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator()).$SettingName) |% {
                    if (-not ($_ -like "*$SettingValue*")){
                        $temp_settings += $_
                    }
                }
            }

            if (-not $($($temp_settings.GetEnumerator()) |? { $_ -like "*$SettingValue*" })){
                Throw "Set-BIOSSettings : Requested setting value could not be found in BIOS settings."
                return
            }

            $nr_chosen_settings = 0
            $($($temp_settings.GetEnumerator()) |% { if ($_ -match "\*"){ $nr_chosen_settings++ }})
            if ($nr_chosen_settings -gt 1){
                Throw "Set-BIOSSettings : Requested value string `"$SettingValue`" for setting `"$SettingName`" returned multiple correct results. Please be more specific with your request."
                return
            }
            
            # Chosen settings equal 0 -> changed settings are NOT a choose-an-option type, but a list of options/devices -> count string comparisons which return true
            if ($nr_chosen_settings -eq 0){
                $($($temp_settings.GetEnumerator()) |% { if ($_ -like "*$SettingValue*"){ $nr_chosen_settings++ }})
                if ($nr_chosen_settings -gt 1){
                    Throw "Set-BIOSSettings : Requested value string `"$SettingValue`" for setting `"$SettingName`" returned multiple correct results. Please be more specific with your request."
                    return
                }
            }

            if (-not $GLOBAL:BCUPARSER_ITERATED_BIOS_TABLE){
                $GLOBAL:BCUPARSER_ITERATED_BIOS_TABLE = $GLOBAL:BCUPARSER_EXPORTED_BIOS_TABLE.GetEnumerator() |? {$_.keys -ne $SettingName}
            }
            else{
                $GLOBAL:BCUPARSER_ITERATED_BIOS_TABLE = $GLOBAL:BCUPARSER_ITERATED_BIOS_TABLE.GetEnumerator() |? {$_.keys -ne $SettingName}
            }
            $GLOBAL:BCUPARSER_ITERATED_BIOS_TABLE += @{$SettingName = $temp_settings}
            $GLOBAL:BCUPARSER_CUSTOMIZED_BIOS_TABLE = $GLOBAL:BCUPARSER_ITERATED_BIOS_TABLE
        }
        else{
            Throw "Set-BIOSSettings : Requested setting name could not be found in BIOS settings."
            return
        }

        # Reset temp variables
        $SettingName = $null
        $SettingValue = $null
    }

    # Settings object modified, now parse it into a file which is supported by BCU
    $temp_setting_title = $null
    $temp_new_setting = $null
    $temp_ExportedConfigFile = Get-Content $GLOBAL:BCUPARSER_exportedCFGpath -Encoding UTF8

    foreach ($settingsgroup in $($GLOBAL:BCUPARSER_CUSTOMIZED_BIOS_TABLE.GetEnumerator())) { 
        if ($settingsgroup.keys){
        
            $temp_setting_title = $settingsgroup.keys
            $temp_new_settings = $settingsgroup.values
            $find_setting = $false

            $line_nr = -1

            $temp_new_settings_current_nr = 0
            $temp_new_settings_all_nr = 0
            $temp_new_settings |% { $temp_new_settings_all_nr++ }

            ForEach ($line in $temp_ExportedConfigFile){
                $line_nr++
                if ($line -eq $temp_setting_title -and $find_setting -eq $false){
                    $find_setting = $true
                }
                elseif ($find_setting -eq $true){
                    if ($line -match "\t"){
                        $temp_ExportedConfigFile[$line_nr] = "`t$($($temp_new_settings.GetEnumerator())[$temp_new_settings_current_nr])"
                        $temp_new_settings_current_nr++
                    }
                    else{
                        $find_setting = $false
                        break
                    }
                }
            }
        }
    }

    # Create a custom cfg file
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($GLOBAL:BCUPARSER_customCFGpath, $temp_ExportedConfigFile, $Utf8NoBomEncoding)


    $CreatePWAttempt = Start-Process $GLOBAL:BCUPARSER_BCUPW_Path -ArgumentList "/f$GLOBAL:BCUPARSER_BIOS_PWD_Path", "/s", "/p$Password" -PassThru -WindowStyle Hidden -Wait

    if ($CreatePWAttempt.ExitCode -ne 0){
        Throw "Set-BIOSSettings : Password creation failed with exitcode `"$($CreatePWAttempt.ExitCode)`"."
        return
    }

    # Import new settings to BIOS
    $ImportCfgAttempt = Start-Process $GLOBAL:BCUPARSER_BCU_Path -ArgumentList "/Set:$($GLOBAL:BCUPARSER_customCFGpath)", "/cspwdfile:$($GLOBAL:BCUPARSER_BIOS_PWD_Path)" -PassThru -WindowStyle Hidden -Wait

    # Check if we were able to change the BIOS settings
    if ($ImportCfgAttempt.ExitCode -ne 0)
    {
        if ($GLOBAL:BCUPARSER_ErrorTable[$ImportCfgAttempt.ExitCode]){
            Throw "Set-BIOSSettings : BIOS settings import failed with exitcode: $($ImportCfgAttempt.ExitCode). Error message: `"$($BCUPARSER_ErrorTable[$ImportCfgAttempt.ExitCode])`""
            return
        }
        else{
            Throw "Set-BIOSSettings : BIOS settings import failed with unsupported exitcode: $($ImportCfgAttempt.ExitCode)."
            return
        }
    }
    else
    {
         Write-Host "Requested BIOS settings have been saved successfully."
    }
    
    if (Test-Path $GLOBAL:BCUPARSER_BIOS_PWD_Path -ErrorAction SilentlyContinue){
        Remove-Item $GLOBAL:BCUPARSER_BIOS_PWD_Path -Force -ErrorAction SilentlyContinue | Out-Null
    }
}
