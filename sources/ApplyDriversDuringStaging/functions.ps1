# This file contains various useful functions for HEM admin purposes.

using namespace System.Windows.Forms
using namespace System.Drawing

########################
##- LOG FILE ACTIONS -##
########################

$GLOBAL:Hemmersbach_Log_File = $null
$GLOBAL:Hemmersbach_Log_Path = $null
$GLOBAL:Hemmersbach_Log_FullPath = $null

function Get-CurrentDate(){
    $_date = (Get-Date -Format "HH:mm:ss dd/MM/yyyy" | Out-String).Trim()
    return $_date
}

function Get-CurrentScriptName(){
    $MainScriptPath = @(Get-PSCallStack).ScriptName |? { $_ -notlike "*\functions.ps1*" }

    if (-not $MainScriptPath){
        $MainScriptPath = "install.ps1"
    }

    if ($MainScriptPath.GetType().Name -ne "String" -and $MainScriptPath.Count -gt 1){
        return $(Split-Path $($MainScriptPath[0]) -Leaf).Split(".")[0]
    }
    else{
        return $(Split-Path $MainScriptPath -Leaf).Split(".")[0]
    }
}

function Get-CurrentTSStepName(){
    $_TSEnv = $null
    $_CurrentStep = ""

    try{
        $_TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        $_CurrentStep = "$($_TSEnv.Value('_SMSTSCurrentActionName'))"
    }
    catch{
        # Do nothing
    }
    
    if (-not (Get-IsStringEmpty $_CurrentStep)){
        return $_CurrentStep.Trim()
    }
    else{
        return "_PSScript"
    }
}

function Get-IsStringEmpty([string]$InputString){
    return $([string]::IsNullOrEmpty($InputString) -or [string]::IsNullOrWhiteSpace($InputString))
}

function Add-MainLogEntry([string]$InputString){
    if (Get-IsStringEmpty $GLOBAL:Hemmersbach_Log_File){
        Start-LogFile "$ENV:SystemRoot`\Logs\HEM\$(Get-CurrentTSStepName)\$(Get-CurrentScriptName)`.log"
    }
    
    $_date = Get-CurrentDate
    "`[$_date`] `/`/===========================================================" | Out-File $GLOBAL:Hemmersbach_Log_FullPath -Append -ErrorAction SilentlyContinue
    "`[$_date`] `|`| $InputString"                                                   | Out-File $GLOBAL:Hemmersbach_Log_FullPath -Append -ErrorAction SilentlyContinue
    "`[$_date`] `\`\===========================================================" | Out-File $GLOBAL:Hemmersbach_Log_FullPath -Append -ErrorAction SilentlyContinue
}

function Add-LogEntry([string]$InputString){
    if (Get-IsStringEmpty $GLOBAL:Hemmersbach_Log_File){
        Start-LogFile "$ENV:SystemRoot`\Logs\HEM\$(Get-CurrentTSStepName)\$(Get-CurrentScriptName)`.log"
    }

    $_date = Get-CurrentDate
    "`[$_date`] $InputString" | Out-File $GLOBAL:Hemmersbach_Log_FullPath -Append -ErrorAction SilentlyContinue
    
}

function Finish-Log([int]$ExitCode){
    if (Get-IsStringEmpty $GLOBAL:Hemmersbach_Log_File){
        Start-LogFile "$ENV:SystemRoot`\Logs\HEM\$(Get-CurrentTSStepName)\$(Get-CurrentScriptName)`.log"
    }

    $_date = CurrentDate
    "`[$_date`] `/`/===========================================================" | Out-File $GLOBAL:Hemmersbach_Log_FullPath -Append -ErrorAction SilentlyContinue
    "`[$_date`] `|`| ENDING SCRIPT WITH VALUE: $ExitCode"                       | Out-File $GLOBAL:Hemmersbach_Log_FullPath -Append -ErrorAction SilentlyContinue
    "`[$_date`] `\`\===========================================================" | Out-File $GLOBAL:Hemmersbach_Log_FullPath -Append -ErrorAction SilentlyContinue
}

function Clear-LogFile(){
     if (-not $(Get-IsStringEmpty $GLOBAL:Hemmersbach_Log_File)){
        Clear-Content -Path $GLOBAL:Hemmersbach_Log_FullPath -Force -ErrorAction SilentlyContinue
    }
}

function Start-LogFile([string]$LogFullPath, [switch]$Append){
    $_LogPath = Split-Path $LogFullPath -Parent
    $_LogName = Split-Path $LogFullPath -Leaf

    $GLOBAL:Hemmersbach_Log_Path = $_LogPath
    $GLOBAL:Hemmersbach_Log_FullPath = $LogFullPath
    $GLOBAL:Hemmersbach_Log_File = $_LogName

    if (-not (Test-Path $_LogPath)){
        New-Item -ItemType Directory -Force -Path $GLOBAL:Hemmersbach_Log_Path -ErrorAction SilentlyContinue | Out-Null
        New-Item -ItemType File -Force -Path $GLOBAL:Hemmersbach_Log_FullPath -ErrorAction SilentlyContinue | Out-Null
    }

    if (-not $Append){
        Clear-LogFile
    }

    Add-MainLogEntry "STARTING SCRIPT: $_LogName"
}

########################################
##- ACTIONS ON FILES AND DIRECTORIES -##
########################################

function Get-IsFolder($Item){
    $_Directory = ""

    if ($Item.GetType().Name -ne "String"){
        $_Directory = $Item.FullName
    }
    else{
        $_Directory = $Item
    }

    if (Test-Path -Path $_Directory -PathType Container){ 
        return $true
    }
    else{
        return $false
    }
}

function LocalAccount-Exists($AccountName){
    $adm = (Get-WmiObject -Class Win32_UserAccount -Filter "Name='$AccountName' and Domain='$ENV:ComputerName'" | Select-Object *).Disabled
    if ($adm -eq $false){
        return $true
    }
    else{
        return $false
    }
}

######################################
##- RUN EXTERNAL COMMANDS AND APPS -##
######################################

function Run-CMDAndGetOutput([string]$Command){
    $_AllArgs = @("/c", $Command)
    $_Output = & "cmd.exe" $_AllArgs | Write-Output
    return $_Output
}

function Run-AsyncPowerShell([ScriptBlock]$ScriptBlock, [int]$Delay, [switch]$InheritWorkingDirectory){
    if (-not $Delay){
        if (-not $InheritWorkingDirectory){
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass", "-Command `"& $ScriptBlock`"" -WindowStyle Hidden
        }
        else{
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass", "-Command `"& $ScriptBlock`"" -WindowStyle Hidden -WorkingDirectory $(Get-Location).Path
        }
    }
    else{
        if (-not $InheritWorkingDirectory){
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass", "-Command `"Start-Sleep $Delay; & $ScriptBlock`"" -WindowStyle Hidden
        }
        else{
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass", "-Command `"Start-Sleep $Delay; & $ScriptBlock`"" -WindowStyle Hidden -WorkingDirectory $(Get-Location).Path
        }
    }
}

function Run-AsyncCMD([string]$Command, [int]$Delay, [switch]$InheritWorkingDirectory){
    if (-not $Delay){
        if (-not $InheritWorkingDirectory){
            Start-Process cmd -ArgumentList "/c", $Command -WindowStyle Hidden
        }
        else{
            Start-Process cmd -ArgumentList "/c", $Command -WindowStyle Hidden -WorkingDirectory $(Get-Location).Path
        }
    }
    else{
        if (-not $InheritWorkingDirectory){
            Start-Process cmd -ArgumentList "/c", "timeout $Delay >nul && $Command" -WindowStyle Hidden
        }
        else{
            Start-Process cmd -ArgumentList "/c", "timeout $Delay >nul && $Command" -WindowStyle Hidden -WorkingDirectory $(Get-Location).Path
        }
    }
}

########################################
##- STRING ENCRYPTION AND DECRYPTION -##
########################################

function Encrypt-String([string]$InputString, [byte[]]$Key){
    $_Key = $Key

    if (-not $_Key){
        [byte[]]$_Key = 5,89,44,63,105,33,61,201,120,45,1,52,214,77,221,19,71,52,57,211,161,38,15,64,18,83,92,66,23,74,12,34
    }

    try{
        $SecureString = Convertto-SecureString "$InputString" -AsPlainText -Force
        $EncryptedString = ConvertFrom-SecureString -SecureString $SecureString -Key $_Key

        return $EncryptedString
    }
    catch{
        Throw "Encrypt-String : Encryption failed with error `"$_`""
    }
}

function Decrypt-String([string]$InputString, [byte[]]$Key){
    $_Key = $Key

    if (-not $_Key){
        [byte[]]$_Key = 5,89,44,63,105,33,61,201,120,45,1,52,214,77,221,19,71,52,57,211,161,38,15,64,18,83,92,66,23,74,12,34
    }

    try{
        $_SecureString = ConvertTo-SecureString -String "$InputString" -Key $_Key
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_SecureString)
        $_Finished = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        return $_Finished
    }
    catch{
        Throw "Decrypt-String : Decryption failed with error `"$(($PSItem | Out-String).Trim())`""
    }
}

######################
##- WINFORMS STUFF -##
######################

function New-InputBoxWindow(
$WindowTitle,
$WindowText,
$ButtonText,
$ButtonActions,
$Regex,
$RegexTip,
$RegexTipInterval,
[switch]$HideInput,
[switch]$ForceUpperCase,
[switch]$ForceLowerCase,
[switch]$DontCloseOnButtonClick,
[switch]$NoCloseButton,
[switch]$NoTaskbar,
[switch]$Force){
    <#

    .SYNOPSIS
    Displays a Windows Forms window with a label, an editable textbox and a button.
    Dependencies from .NET Framework may be required to run this command.
    Text and functionality of these elements are customizable.

    .DESCRIPTION
    WindowTitle - a string, displayed on the title bar.
    WindowText - a string, displayed inside the window.
    ButtonText - a string, displayed on a button.
    ButtonActions - scriptblock, which is invoked as soon as the button is pushed.
    Regex - a pattern, according to which we specify what can be entered.
    RegexTip - information which will be displayed to user upon entering an invalid string.
    RegexTipInterval - amount of characters typed, after which the RegexTip text will be displayed. By default it's 10 characters.
    HideInput - if active, this switch makes it so that the text in box is displayed as stars (*).
    ForceUpperCase - forces the input text to be uppercase.
    ForceLowerCase - forces the input text to be lowercase.
    DontCloseOnButtonClick - if active, this switch makes it so that the window does not close after the button is pressed.
    NoCloseButton - if active, the window does not have an "X" button in the top right corner.
    NoTaskbar - process won't appear in Windows Taskbar.
    Force - if active, can allow usage of both switches DontCloseOnButtonClick and NoCloseButton at once.

    .EXAMPLE
    New-InputBoxWindow -WindowTitle "Computer Name" -WindowText "Provide your computer name." -ButtonText "OK" -Regex "[PC|NB|TC]-HEM000[0-9][0-9][0-9][0-9][0-9]$" -RegexTip "Computername can be found on a sticker." -ForceUpperCase -NoCloseButton
    
    .EXAMPLE
    New-InputBoxWindow -WindowTitle "First window" -WindowText "This is the first window." "OK" -ForceUpperCase -ButtonActions {New-InputBoxWindow "Second window" "Surprise! This is window #2." "Wow..." -ForceLowerCase}

    .EXAMPLE
    New-InputBoxWindow -WindowTitle "Annoying Window! :)" -WindowText "You can't easily close this one!" "Geez..." -NoCloseButton -DontCloseOnButtonClick -NoTaskbar -Force

    .NOTES
    DontCloseOnButtonClick and NoCloseButton cannot be active at the same time (can be forced).
    ForceUpperCase and ForceLowerCase cannot be active at the same time.

    #>
    
    if ($DontCloseOnButtonClick -and $NoCloseButton -and -not $Force){
        Throw "New-InputBoxWindow : All ways of closing the form have been disabled! Use parameter `"Force`" if you want to do this regardless."
    }

    if ($ForceUpperCase -and $ForceLowerCase){
        Throw "New-InputBoxWindow : Forcing uppercase and lowercase input cannot be done at the same time!"
    }

    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    Add-Type -AssemblyName PresentationCore,PresentationFramework
    Add-Type -AssemblyName System.Windows.Forms

    $Form = New-Object System.Windows.Forms.Form
    $Form.Size = New-Object System.Drawing.Size(350, 186)
    $Form.Text = $WindowTitle
    $Form.AutoScroll = $true
    $Form.MinimizeBox = $false
    $Form.MaximizeBox = $false
    $Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle

    $iconBytes = [Convert]::FromBase64String($GLOBAL:ApplicationHemIconBase64)
    $stream = New-Object IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
    $stream.Write($iconBytes, 0, $iconBytes.Length)
    $Form.Icon = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument $stream).GetHIcon())
    
    if ($NoCloseButton){
        $Form.ControlBox = $false
    }

    if ($NoTaskbar){
        $Form.ShowInTaskbar = $false
    }

    $Font = New-Object System.Drawing.Font("Times New Roman", 10)
    $Form.Font = $Font

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20,17)
    $label.Size = New-Object System.Drawing.Size(285,20)
    $label.Text = $WindowText
    $Form.Controls.Add($label)

    $GLOBAL:_CurrentlyDisplayedFormText = ""
    $GLOBAL:_CurrentlyDisplayedFormButton = $null
    $GLOBAL:_CurrentlyDisplayedFormToolTip = $null
    $GLOBAL:_NumTimesToolTipDisplayed = 0

    if ($HideInput){
        $textBox = New-Object System.Windows.Forms.MaskedTextBox
        $textBox.PasswordChar = '*'
    }
    else{
        $textBox = New-Object System.Windows.Forms.TextBox
    }
    $textBox.Text = ""
    $textBox.Location = New-Object System.Drawing.Point(22,53)
    $textBox.Size = New-Object System.Drawing.Size(290,20)
    $textBox.MaxLength = 36
    $textBox.Font = New-Object System.Drawing.Font("Times New Roman", 11, [System.Drawing.FontStyle]::Regular)
    $textBox.Add_KeyUp({
        if ($Regex -and -not $(Get-IsStringEmpty $Regex) -and $textBox.Text -match $Regex){
            $GLOBAL:_CurrentlyDisplayedFormButton.Enabled = $true
        }
        elseif (-not $Regex -or (Get-IsStringEmpty $Regex)){
            $GLOBAL:_CurrentlyDisplayedFormButton.Enabled = $true
        }
        else{
            $GLOBAL:_CurrentlyDisplayedFormButton.Enabled = $false
            $GLOBAL:_NumTimesToolTipDisplayed = $GLOBAL:_NumTimesToolTipDisplayed + 1

            $TipInterval = 10
            if ($RegexTipInterval){
                $TipInterval = $RegexTipInterval
            }

            if ($GLOBAL:_CurrentlyDisplayedFormToolTip -and ($GLOBAL:_NumTimesToolTipDisplayed -eq $TipInterval)){
                $GLOBAL:_NumTimesToolTipDisplayed = 0
                $pos = [System.Drawing.Point]::new($textBox.Right, $textBox.Top)
                $GLOBAL:_CurrentlyDisplayedFormToolTip.Show($RegexTip, $Form, $pos, 2000)
            }
        }
    })

    if ($ForceUpperCase){
        $textBox.CharacterCasing = [System.Windows.Forms.CharacterCasing]::Upper
    }
    elseif($ForceLowerCase){
        $textBox.CharacterCasing = [System.Windows.Forms.CharacterCasing]::Lower
    }

    $Form.Controls.Add($textBox)

    $Button = New-Object System.Windows.Forms.Button
    $Button.Location = New-Object System.Drawing.Point(110, 100)
    $Button.Size = New-Object System.Drawing.Size(110,29)
    $Button.Text = $ButtonText
    if (Get-IsStringEmpty $Regex -or $textBox.Text -match $Regex){
        $Button.Enabled = $true
    }
    else{
        $Button.Enabled = $false
    }

    if (-not $DontCloseOnButtonClick){
        $Button.DialogResult = [System.Windows.Forms.DialogResult]::OK
    }

    $GLOBAL:_CurrentlyDisplayedFormButton = $Button
    $Button.Add_Click({
        if ($ButtonActions){
            Invoke-Command $ButtonActions
        }

        if (-not $DontCloseOnButtonClick){
            $GLOBAL:_CurrentlyDisplayedFormText = $textBox.Text

            $Form.Dispose()
            $Form.Close()
        }
    })
    $Form.Controls.Add($Button)
    $Form.AcceptButton = $Button

    if ($Regex -and -not $(Get-IsStringEmpty $Regex) -and $RegexTip -and -not $(Get-IsStringEmpty $RegexTip)){
        $toolTip = New-Object System.Windows.Forms.ToolTip
        $toolTip.IsBalloon = $true
        $toolTip.UseFading = $false
        $toolTip.UseAnimation = $false
        $GLOBAL:_CurrentlyDisplayedFormToolTip = $toolTip
    }

    $Form.Add_Shown({$Form.Activate()})
    [void] $Form.ShowDialog()

    $text_to_return = $GLOBAL:_CurrentlyDisplayedFormText

    $GLOBAL:_CurrentlyDisplayedFormText = $null
    $GLOBAL:_CurrentlyDisplayedFormButton = $null
    $GLOBAL:_CurrentlyDisplayedFormToolTip = $null
    $GLOBAL:_NumTimesToolTipDisplayed = $null

    if (-not $(Get-IsStringEmpty $text_to_return)){
        return $text_to_return
    }
    else{
        return $null
    }
}


#######################
##- C# SHENANINGANS -##
#######################

# Requires .NET libraries! Won't work on Windows 10 1511 and some 1809s.
function Set-WindowStyle {
    param(
        [Parameter()]
        [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
                     'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
                     'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
        $Style = 'SHOW',
        [Parameter()]
        $MainWindowHandle = (Get-Process -Id $pid).MainWindowHandle
    )

    $WindowStates = @{
        FORCEMINIMIZE   = 11; HIDE            = 0
        MAXIMIZE        = 3;  MINIMIZE        = 6
        RESTORE         = 9;  SHOW            = 5
        SHOWDEFAULT     = 10; SHOWMAXIMIZED   = 3
        SHOWMINIMIZED   = 2;  SHOWMINNOACTIVE = 7
        SHOWNA          = 8;  SHOWNOACTIVATE  = 4
        SHOWNORMAL      = 1
    }
    Write-Verbose ("Set Window Style {1} on handle {0}" -f $MainWindowHandle, $($WindowStates[$style]))

    $Win32ShowWindowAsync = Add-Type –memberDefinition @” 
    [DllImport("user32.dll")] 
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
“@ -name “Win32ShowWindowAsync” -namespace Win32Functions –passThru

    $Win32ShowWindowAsync::ShowWindowAsync($MainWindowHandle, $WindowStates[$Style]) | Out-Null
}

#Below code lets us operate on taskbar and mouse cursor - we can hide/show it anytime
$Source = @"
using System;
using System.Runtime.InteropServices;

public class Taskbar
{
    [DllImport("user32.dll")]
    private static extern int FindWindow(string className, string windowText);
    [DllImport("user32.dll")]
    private static extern int ShowWindow(int hwnd, int command);

    private const int SW_HIDE = 0;
    private const int SW_SHOW = 1;

    protected static int Handle
    {
        get
        {
            return FindWindow("Shell_TrayWnd", "");
        }
    }

    private Taskbar()
    {
        // hide ctor
    }

    public static void Show()
    {
        ShowWindow(Handle, SW_SHOW);
    }

    public static void Hide()
    {
        ShowWindow(Handle, SW_HIDE);
    }
}
"@
Add-Type -ReferencedAssemblies 'System', 'System.Runtime.InteropServices' -TypeDefinition $Source -Language CSharp


#########
#-OTHER-#
#########

$GLOBAL:ApplicationHemIconBase64 = "AAABAAUAEBAAAAEAIABoBAAAVgAAABgYAAABACAAiAkAAL4EAAAgIAAAAQAgAKgQAABGDgAAMDAAAAEAIACoJQAA7h4AAElJAAABAAgAQB"+
"0AAJZEAAAoAAAAEAAAACAAAAABACAAAAAAAAAEAAATCwAAEwsAAAAAAAAAAAAA/////////////////////////////////////////////////////////////"+
"//////////////////////////////////////////////+/v//4+z8//X4/v//////////////////////////////////////////////////////////////"+
"/////////P3//3ei8/9ilPH/vdL5//D1/v/w9f7///////////////////////////////////////////////////////z9//9qmfL/GmPq/1GJ7/+rxvf/VIv"+
"v/5G09f/t8/3////////////////////////////////////////////8/f//aZnx/x1l6v9RiO//or/3/yJo6/8rbuz/zt37//////////////////////////"+
"///////////////////P3//2iY8f8dZer/Uonv/6G/9v8lauv/LnHs/8/e+/////////////////////////////////////////////z9//9omPH/HWXq/1SK7"+
"/+hv/b/JGrr/zBy7P/R4Pv////////////////////////////////////////////8/f//Zpfx/x1l6v9Vi/D/n732/yRp6/8xcuz/0+H7////////////////"+
"////////////////////////////+/3//2aX8f8eZuv/O3rt/12R8P8iaOv/MnPs/9Xi+/////////////////////////////////////////////v9//9ml/H"+
"/H2fr/yJp6/8fZuv/IWfr/zN07P/W4/v////////////////////////////////////////////7/P//ZJbx/x1l6v9Kg+//eKPz/zV17f9Df+7/3+n8//////"+
"//////////////////////////////////////8fb+/16R8P8cZOr/ZJXx//X4/v/X5Pv/1uP7//z9/////////////////////////////////////////////"+
"6rF9/8qbuz/Hmbr/2WW8f/6/P/////////////////////////////////////////////////////////////G2Pr/UYjv/yRq6/9klvH/+/z/////////////"+
"/////////////////////////////////////////////////////+7z/f+vyfj/nr32//z9///////////////////////////////////////////////////"+
"///////////////////////////z9/////////////////////////////////////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoAAAAGAAAADAAAAABACAAAAAAAAAJAAATCwAAEwsAAAAAAAAAAAAA/////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////L2/v/R4Pv/9vn+//////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////93o/P9Gge7/Z5jx/7nP+f/x9v7//////////////////////////////////////////////////////////////////////////////"+
"////////////////////////93o/P84d+3/H2br/ylt6/93ovP/5+79/5289v/D1vr/8PX+////////////////////////////////////////////////////"+
"/////////////////////////////93o/P84d+3/Imjr/x9m6/9Ui+//2eX8/z987v8rb+z/Uonv/6bC9//9/v/////////////////////////////////////"+
"//////////////////////////////////9vn/P82du3/Imjr/yBn6/9ZjvD/2eX8/0B97v8gZ+v/HWXq/16S8P/6/P////////////////////////////////"+
"///////////////////////////////////////9vn/P82du3/Imjr/yBn6/9ZjvD/2eX8/0B97v8haOv/H2fr/2OV8f/7/P///////////////////////////"+
"////////////////////////////////////////////9vn/P82du3/Imjr/yBn6/9bkPD/2OT7/z587f8haOv/H2fr/2aX8f/7/P//////////////////////"+
"/////////////////////////////////////////////////9vn/P82du3/Imjr/yBn6/9ckPD/2OT7/z577f8haOv/IGfr/2iY8f/8/f/////////////////"+
"//////////////////////////////////////////////////////9rm/P81de3/Imjr/yBn6/9ekfD/1+T7/z177f8haOv/IGfr/2ua8v/8/f////////////"+
"///////////////////////////////////////////////////////////9nl/P80dOz/Imjr/yBn6/9gkvH/1uP7/zt57f8iaOv/IGfr/22c8v/8/f///////"+
"////////////////////////////////////////////////////////////////9nl/P80dOz/Imjr/yFn6/9Mhe//nbz2/y5x7P8iaev/IGfr/3Cd8v/9/f//"+
"/////////////////////////////////////////////////////////////////////9nl/P80dOz/Imjr/yNp6/8kauv/KG3r/yNp6/8jaev/IGfr/3Kf8v/"+
"9/v///////////////////////////////////////////////////////////////////////9nl/P80dOz/Imjr/yNp6/8iaOv/IGfr/yJp6/8jaev/IGfr/3"+
"Wh8v/9/v///////////////////////////////////////////////////////////////////////9jk+/8yc+z/Imjr/yFo6/9KhO//YJPx/ylt7P8fZuv/H"+
"GXq/3mk8//+/v///////////////////////////////////////////////////////////////////////9fk+/8xc+z/Imjr/yBn6/96pPP/8fb+/67I+P9k"+
"lfH/YZPx/7/T+f//////////////////////////////////////////////////////////////////////+/z//8na+v8wcuz/Imjr/yBn6/97pfP//v7////"+
"////6+///+fv+////////////////////////////////////////////////////////////////////////////1eP7/06H7/8ma+v/I2nr/yBn6/99p/P///"+
"//////////////////////////////////////////////////////////////////////////////////////////////0N/7/yxv7P8gZ+v/I2nr/yBn6/9/q"+
"PP/////////////////////////////////////////////////////////////////////////////////////////////////8PX+/5m59v9Mhe//Jmvr/x1l"+
"6v+BqfP////////////////////////////////////////////////////////////////////////////////////////////////////////////p8P3/qcX"+
"3/1iN8P+MsfT///////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"////////D1/v/m7v3//////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAACAAAABAAAAAAQAgAAAAAAAAEAA"+
"AEwsAABMLAAAAAAAAAAAAAP////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"////////////////////////////////////////////////////////////////////////////////////////////////V4vv/yNn6//b5/v////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"////////////////////6K/9/8zdOz/a5ry/7vQ+f/y9v7/////////////////////////////////////////////////////////////////////////////"+
"////////////////////////////////////////////////////////////////////o8D3/yJo6/8gZ+v/LG/s/1yQ8P+3zvj//f7//9/p/P/q8f3//v7////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////+jwPf/I2"+
"nr/yNp6/8iaev/HWXq/1uP8P/3+f7/f6jz/0qE7/+HrvT/xdf6/+/0/v/+/////////////////////////////////////////////////////////////////"+
"////////////////////////////////////////6K/9/8jaev/I2nr/yNp6/8gZ+v/XpHw//f5/v91ofL/HWXq/yFo6/8vcez/VYvw/83d+v//////////////"+
"////////////////////////////////////////////////////////////////////////////////////////n732/yJo6/8jaev/I2nr/yBn6/9hk/H/9vn"+
"+/3Kf8v8gZ+v/I2nr/yJo6/8gZ+v/rsj4//////////////////////////////////////////////////////////////////////////////////////////"+
"////////////+evfb/Imjr/yNp6/8jaev/IGfr/2GT8f/2+f7/cp/y/yBn6/8jaev/I2nr/yRq6/+yyvj//////////////////////////////////////////"+
"////////////////////////////////////////////////////////////5699v8iaOv/I2nr/yNp6/8gZ+v/YpTx//b5/v9yn/L/IGfr/yNp6/8jaev/JWvr"+
"/7TM+P//////////////////////////////////////////////////////////////////////////////////////////////////////nr32/yJo6/8jaev"+
"/I2nr/yBn6/9llvH/9vn+/26c8v8gZ+v/I2nr/yNp6/8ma+v/tc34//////////////////////////////////////////////////////////////////////"+
"////////////////////////////////+evfb/Imjr/yNp6/8jaev/IGfr/2aX8f/2+f7/bpzy/yBn6/8jaev/I2nr/yds6/+4zvn//////////////////////"+
"////////////////////////////////////////////////////////////////////////////////5699v8iaOv/I2nr/yNp6/8gZ+v/Zpfx//b5/v9unPL/"+
"IGfr/yNp6/8jaev/KG3s/7nP+f/////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////m7v2/yFo6/8jaev/I2nr/yBn6/9pmfH/9fj+/2qa8f8gZ+v/I2nr/yJp6/8qbez/vNH5//////////////////////////////////////////////////"+
"////////////////////////////////////////////////////+auvb/IWfr/yNp6/8jaev/IGfr/2ua8v/1+P7/aZnx/yBn6/8jaev/Imnr/ypu7P+90vn//"+
"////////////////////////////////////////////////////////////////////////////////////////////////////5q69v8hZ+v/I2nr/yNp6/8g"+
"Z+v/XJDw/9nl/P9QiO//IWfr/yNp6/8iaev/LG/s/8DU+f/////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////mrr2/yFn6/8jaev/I2nr/yNp6/8qbuz/Qn7u/yds6/8jaev/I2nr/yJp6/8tcOz/wdX5//////////////////////////////"+
"////////////////////////////////////////////////////////////////////////+auvb/IWfr/yNp6/8jaev/I2nr/yNp6/8haOv/I2nr/yNp6/8ja"+
"ev/Imjr/y5x7P/E1/r//////////////////////////////////////////////////////////////////////////////////////////////////////5q6"+
"9v8hZ+v/I2nr/yNp6/8jaev/IWjr/yFo6/8jaev/I2nr/yNp6/8iaOv/L3Hs/8XX+v/////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////l7j2/yBn6/8jaev/I2nr/yJo6/9FgO7/S4Tv/yRq6/8haOv/I2nr/yJo6/8wcuz/yNr6//////////"+
"////////////////////////////////////////////////////////////////////////////////////////////+Vt/X/H2br/yNp6/8jaev/IWjr/4yx9"+
"f/k7f3/k7X1/z987f8iaOv/IWjr/0iD7v/e6Pz/////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////5W39f8fZuv/I2nr/yNp6/8haOv/krX1///////9/v//2OX7/6rF9/+nw/f/0+H7//3+///////////////////////////////////////"+
"///////////////////////////////////////////////////////z9///x9v7/j7L1/x9n6/8jaev/I2nr/yFo6/+TtfX///////////////////////////"+
"//////////////////////////////////////////////////////////////////////////////////////////////////////8fb+/3Ge8v89e+3/Imjr/"+
"yNp6/8jaev/IWjr/5a49f//////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////w9f7/Tobv/x9m6/8jaev/I2nr/yNp6/8haOv/l7j2///////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////L2/v9ckPD/IGfr/yFo6/8jaev/I2nr/yJo6/+bu/b///////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"f7//9jk+/+OsvX/R4Lu/yVq6/8gZ+v/IWjr/5y89v//////////////////////////////////////////////////////////////////////////////////"+
"//////////////////////////////////////////////////////////7+///j7P3/ob/2/1WL8P8obOv/nbz2///////////////////////////////////"+
"/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7f"+
"P9/7LK+P/J2vr//////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////////////////7/////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgAA"+
"AAwAAAAYAAAAAEAIAAAAAAAACQAABMLAAATCwAAAAAAAAAAAAD/////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////+/v///f7////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////////////////f6fz/jrL1/8vc+v/1+P7//////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////S4Pv/NXXt/zR17P9zn/L/vNH5//L2/v/////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////////////////////////////////////T4fv/Nnbt/yJo6/8haOv/MnTs/2KU8f+wyvj/6fD9//7+/"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////T4fv/Nnbt/yJo6/8jaev/Imjr/yFn6/8pbez"+
"/VIrv/7XN+P//////8fX+/8bY+v/k7fz//f7///////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////////////////////////////////////////////////////////T4fv/Nnbt/yJo6/8jaev/I2nr/"+
"yNp6/8jaev/HGXq/22c8v//////3uj8/1aM8P9Jg+7/fqjz/8DU+f/o7/3/+/3/////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////T4fv/Nnbt/yJo6/8"+
"jaev/I2nr/yNp6/8jaev/Hmbr/26c8v//////3un8/0qE7/8dZer/Imnr/ytv7P9Sie//i7D0/8PW+v/z9/7///////////////////////////////////////"+
"/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////S4Pv/N"+
"XXt/yJo6/8jaev/I2nr/yNp6/8jaev/H2br/3Og8v//////3Of8/0mD7v8gZ+v/I2nr/yNp6/8haOv/Imjr/zJz7P+evfb/////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"////P3/v/MXPs/yJp6/8jaev/I2nr/yNp6/8jaev/H2fr/3ah8v//////2eX8/0eB7v8gZ+v/I2nr/yNp6/8jaev/I2nr/x1l6v+LsPT///////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"//////////////P3vv/MHLs/yJp6/8jaev/I2nr/yNp6/8jaev/H2fr/3ah8v//////2eX8/0eB7v8gZ+v/I2nr/yNp6/8jaev/I2nr/yBn6/+Qs/X/////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"////////////////////////P3vv/MHLs/yJp6/8jaev/I2nr/yNp6/8jaev/H2fr/3ah8v//////2eX8/0eB7v8gZ+v/I2nr/yNp6/8jaev/I2nr/yFn6/+QtP"+
"X//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"//////////////////////////////////P3vv/MHLs/yJp6/8jaev/I2nr/yNp6/8jaev/H2fr/3ai8v//////2eX8/0eB7v8gZ+v/I2nr/yNp6/8jaev/I2nr"+
"/yJo6/+TtfX////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"////////////////////////////////////////////P3vv/MHLs/yJp6/8jaev/I2nr/yNp6/8jaev/IGfr/3ql8///////1+P7/0SA7v8hZ+v/I2nr/yNp6/"+
"8jaev/I2nr/yNp6/+XuPX//////////////////////////////////////////////////////////////////////////////////////////////////////"+
"//////////////////////////////////////////////////////P3vv/MHLs/yJp6/8jaev/I2nr/yNp6/8jaev/IWjr/32m8///////1eL7/0N/7v8hZ+v/"+
"I2nr/yNp6/8jaev/I2nr/yNp6/+XuPX////////////////////////////////////////////////////////////////////////////////////////////"+
"////////////////////////////////////////////////////////////////P3vv/MHLs/yJp6/8jaev/I2nr/yNp6/8jaev/IWjr/32m8///////1eL7/0"+
"N/7v8hZ+v/I2nr/yNp6/8jaev/I2nr/yRq6/+auvb//////////////////////////////////////////////////////////////////////////////////"+
"//////////////////////////////////////////////////////////////////////////P3vv/MHLs/yJp6/8jaev/I2nr/yNp6/8jaev/IWjr/32m8///"+
"////1eL7/0N/7v8hZ+v/I2nr/yNp6/8jaev/I2nr/yZr6/+dvPb////////////////////////////////////////////////////////////////////////"+
"////////////////////////////////////////////////////////////////////////////////////P3vv/MHLs/yJp6/8jaev/I2nr/yNp6/8jaev/IW"+
"jr/32n8///////1eL7/0N/7v8hZ+v/I2nr/yNp6/8jaev/I2nr/yZr6/+dvPb//////////////////////////////////////////////////////////////"+
"//////////////////////////////////////////////////////////////////////////////////////////////N3fr/LXDs/yNp6/8jaev/I2nr/yNp"+
"6/8jaev/Imjr/4Kp9P//////0eD7/z987f8haOv/I2nr/yNp6/8jaev/Imnr/yds6/+gvvf////////////////////////////////////////////////////"+
"////////////////////////////////////////////////////////////////////////////////////////////////////////M3Pr/K27s/yNp6/8jae"+
"v/I2nr/yNp6/8jaev/Imjr/4Sr9P//////0N/7/z587f8haOv/I2nr/yNp6/8jaev/Imnr/yht7P+kwff//////////////////////////////////////////"+
"//////////////////////////////////////////////////////////////////////////////////////////////////////////////////M3Pr/K27s"+
"/yNp6/8jaev/I2nr/yNp6/8jaev/Imjr/4Sr9P//////0N/7/z587f8haOv/I2nr/yNp6/8jaev/Imnr/yht7P+kwff////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/M3Pr/K27s/yNp6/8jaev/I2nr/yNp6/8jaev/IWjr/32m8///////v9T5/zJz7P8iaOv/I2nr/yNp6/8jaev/Imjr/ypt7P+nw/f//////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////M3Pr/K27s/yNp6/8jaev/I2nr/yNp6/8jaev/IWjr/0eB7v+lwvf/aJjx/yJp6/8jaev/I2nr/yNp6/8jaev/Imjr/ytu7P+qxff////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////M3Pr/K27s/yNp6/8jaev/I2nr/yNp6/8jaev/I2nr/yJo6/8lauv/Imnr/yNp6/8jaev/I2nr/yNp6/8jaev/Imjr/ytu7P+qxff//"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////M3Pr/K27s/yNp6/8jaev/I2nr/yNp6/8jaev/I2nr/yNp6/8jaev/I2nr/yNp6/8jaev/I2nr/yNp6/8jaev/Imjr/yx"+
"v7P+uyPj///////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////////M3Pr/K27s/yNp6/8jaev/I2nr/yNp6/8jaev/I2nr/yNp6/8jaev/I2nr/yNp6/8jaev/I2nr/yNp6/8ja"+
"ev/Imjr/y1w7P+xyvj/////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////M3Pr/K27s/yNp6/8jaev/I2nr/yNp6/8jaev/I2nr/yJo6/8iaOv/I2nr/yNp6/8jaev/I2n"+
"r/yNp6/8jaev/Imjr/y1w7P+xyvj///////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////////////////////L2/r/KW3s/yNp6/8jaev/I2nr/yNp6/8jaev/JGnr/zN07P8wcuz/IWfr/yNp6"+
"/8jaev/I2nr/yNp6/8jaev/Imjr/y9x7P+1zfj/////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////I2vr/JWvr/yNp6/8jaev/I2nr/yNp6/8jaev/Km3s/5y79v+3zvj"+
"/XpLw/ylt7P8haOv/I2nr/yNp6/8jaev/IWjr/zFz7P+90vn///////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////////////////////////////////////////I2vr/JWrr/yNp6/8jaev/I2nr/yNp6/8iaev/LXDs/"+
"7rQ+f//////6/H9/6bC9/9Nhu//JWrr/x5m6/8fZuv/I2nr/1OK7//i6/z/////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////I2vr/JWrr/yNp6/8jaev/I2nr/yNp6/8"+
"iaev/LnDs/73S+f/////////////////i6/z/nbz2/4Kq9P98pvP/mrr2/9Xi+//+//////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////////////////////////////////////////////////////////////I2vr/JWrr/yNp6/8jaev/I"+
"2nr/yNp6/8iaev/LnDs/73S+f////////////////////////////3+///7/P//////////////////////////////////////////////////////////////"+
"////////////////////////////////////////////////////////////////////////////////////////////////////8PX+//H2/v/C1vr/JWrr/yN"+
"p6/8jaev/I2nr/yNp6/8iaev/LnDs/77T+f////////////////////////////////////////////////////////////////////////////////////////"+
"//////////////////////////////////////////////////////////////////////////////////////////////////////////////v9P5/1mO8P9aj"+
"vD/JGrr/yNp6/8jaev/I2nr/yNp6/8iaev/L3Hs/8PW+v//////////////////////////////////////////////////////////////////////////////"+
"////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////ts3"+
"4/yNp6/8iaOv/I2nr/yNp6/8jaev/I2nr/yNp6/8iaev/L3Hs/8TX+v////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////t874/yVr6/8jaev/I2nr/yNp6/8jaev/I2nr/yNp6/8iaev/L3Hs/8TX+v//////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////t874/yNp6/8haOv/I2nr/yNp6/8jaev/I2nr/yNp6/8iaev/MHLs/8ja+v////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////1+T7/2mZ8f84d+3/IWjr/yJo6/8jaev/I2nr/yNp6/8iaOv/MHLs/8zc+v//////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////f6/v/G2Pr/gKj0/zx67f8kauv/IGfr/yJp6/8iaev/MHLs/8vc+v////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////+Pv+/9jk/P+PsvX/TYXv/yds6/8gZ+v/MHLs/83d+v//////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////////////////////////////////////////////////4er8/6LA9/9XjPD/Onnt/9Lh+/////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////////////////////////////////////////////////////////////////////////7////r8v3/vtP5/+jv"+
"/f/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"+
"/////////////////////////////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoAAAASQAAAJIAAAABAAgAAAAAAKwVAAATCwAAEwsAAAABAAAAAQAA////AO3z/QCS"+
"tfUA4Or8AN3o/AB7pfMAK27sACNp6wDY5fsAydr6AGSV8QDW4/sA/P3/AK/I+ABMhe8Ay9z6APL2/gCauvYAOnntAOXt/QCDqvQALXDsAOjv/QBckPAAvtP5AEq"+
"D7wBZjvAAw9b6AO/0/gC0zPgAscr4APf6/gCVt/UAqsX3AD177QAobesA2+b8AKTB9wBSie8Al7j2AHah8wBml/EAfqfzADBy7ABxnvIAaZnxALnP+QC3zvgAP3"+
"zuAGGT8QBXjPAANXXtAEWA7gCAqfMAi7D0AEeC7gAzdOwAnbz2AI2x9QBzoPIAkLP1AEJ+7gBUi+8Azt37APX4/gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJgUEAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABkHBy0/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZBwcHBz4vAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGQcHBwcHBz0lHwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAABkHBwcHBwcHBzg8AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZBw"+
"cHBwcHBwcHBwYAAAAhKS8fAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGQcHBwcHBwcHBwcHAAAAJQcHF"+
"TsYDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABkHBwcHBwcHBwcHBwAAACUHBwcHBzMqDwAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAZBwcHBwcHBwcHBwcAAAAlBwcHBwcHBwcSOggAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGQcHBwcHBwcHBwcVAAAAOQcHBwcHBwcHBwcHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAADAHBwcHBwcHBwcHKwAAACcHBwcHBwcHBwcHBwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAiBwcHBwcHB"+
"wcHBysAAAAnBwcHBwcHBwcHBwYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIgcHBwcHBwcHBwcrAAAAJwcHBwcHBwcH"+
"BwcrAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACIHBwcHBwcHBwcHKwAAACcHBwcHBwcHBwcHKwAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAiBwcHBwcHBwcHBysAAAAnBwcHBwcHBwcHBysAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAIgcHBwcHBwcHBwcrAAAAJwcHBwcHBwcHBwc4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAACIHBwcHBwcHBwcHOAAAACAHBwcHBwcHBwcHIgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAiBwcHBwcHBwcHByIA"+
"AAA2BwcHBwcHBwcHByIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIgcHBwcHBwcHBwciAAAANgcHBwcHBwcHBwciAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACIHBwcHBwcHBwcHIgAAADYHBwcHBwcHBwcHIgAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAiBwcHBwcHBwcHByIAAAA2BwcHBwcHBwcHBzcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAIgcHBwcHBwcHBwciAAAANgcHBwcHBwcHBwcZAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACIH"+
"BwcHBwcHBwcHIgAAADYHBwcHBwcHBwcHGQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAiBwcHBwcHBwcHByIAAAA2Bwc"+
"HBwcHBwcHBxkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMwcHBwcHBwcHBwc0AAAANQcHBwcHBwcHBwcOAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACsHBwcHBwcHBwcHGQAAACoHBwcHBwcHBwcHMgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAArBwcHBwcHBwcHBxkAAAAqBwcHBwcHBwcHBzIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAKwcHBwcHBwcHBwcZAAAAKgcHBwcHBwcHBwcyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACsHBwcHBwc"+
"HBwcHGQAAAAUHBwcHBwcHBwcHMgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAArBwcHBwcHBwcHBzAAAAAZBwcHBwcHBw"+
"cHBzEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKwcHBwcHBwcHBwcHLgAvBwcHBwcHBwcHBwcKAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACsHBwcHBwcHBwcHBwcSBwcHBwcHBwcHBwcHCgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAArBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAKwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwctAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACsHBwcHBwcHBwcHBw"+
"cHBwcHBwcHBwcHBwcHLAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAArBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBywAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcsAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACsHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHLAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAVBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHByoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABw"+
"cHBwcHBwcHBwcoCCkHBwcHBwcHBwcHBwcqAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcHBwcHBwcHBwcHJQAADyYHB"+
"wcHBwcHBwcHJwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHBwcHBwcHBwcHByEAAAAAHiIHBwcHBwcHIyQAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABwcHBwcHBwcHBwceAAAAAAAfIBUHBwcVChsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcHBwcHBwcHBwcHHgAAAAAAAAAAAAgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAHBwcHBwcHBwcHBx4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABwcHBwcHB"+
"wcHBwceAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFhsAHAcHBwcHBwcHBwcHHQAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgHGRoHBwcHBwcHBwcHBxgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIBwcHBwcHBwcHBwcHBwcYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAACAcHBwcHBwcHBwcHBwcHGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AgHBwcHBwcHBwcHBwcHBxgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIBwcHBwcHBwcHBwcHBwcY"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAcHBwcHBwcHBwcHBwcHDwAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABYXBwcHBwcHBwcHBwcHBw8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABMUFQcHBwcHBwcHBwcPAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAABAREgcHBwcHBwcHDwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAwNDgcHBwcHBw8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJCgcHBwcLAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEBQYHCAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAgMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"+
"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="