using namespace System.Windows.Forms
using namespace System.Drawing

param($URLFileName, $FullSize)

. "$PSScriptRoot`\functions.ps1"

$NewSize = $([math]::round($($(Get-Item "$PSScriptRoot`\HPSoftPaqDownloadData`\$URLFileName" -ErrorAction SilentlyContinue).Length / 1Mb), 1))

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
Add-Type -AssemblyName PresentationCore,PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$ScreenResolutionData = (((Get-WmiObject -Class Win32_VideoController).VideoModeDescription) | Out-String).Trim()
$ScreenResX = $ScreenResolutionData.Split("x")[0].Trim()
$ScreenResY = $ScreenResolutionData.Split("x")[1].Trim()

$FormSizeX = $ScreenResX/3
$FormSizeY = $ScreenResY/4

$ProgressSizeX = $ScreenResX/3.3
$ProgressSizeY = $ScreenResY/30
$ProgressLocationX = ($FormSizeX - $ProgressSizeX) / 2
$ProgressLocationY = ($FormSizeY - $ProgressSizeY) / 2

$LabelSizeX = $ProgressSizeX
$LabelSizeY = $ScreenResY/30
$LabelLocationX = $ProgressLocationX
$LabelLocationY = $ProgressLocationY / 3

$Form = New-Object System.Windows.Forms.Form
$Form.Size = New-Object System.Drawing.Size($FormSizeX, $FormSizeY)
$Form.Text = "Downloading the drivers"
$Form.AutoScroll = $true
$Form.MinimizeBox = $false
$Form.MaximizeBox = $false
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$Form.ControlBox = $false
$Form.TopMost = $true
$Form.BackColor = "White"
$Form.Enabled = $false # No interaction!

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point($LabelLocationX, $LabelLocationY)
$label.Size = New-Object System.Drawing.Size($LabelSizeX, $LabelSizeY)
$label.Text = "Download in progress... ($NewSize`/$FullSize)"
$label.Font = [System.Drawing.Font]::new("SegoeUI", 15, [System.Drawing.FontStyle]::Bold)
$label.UseCompatibleTextRendering = $true
$Form.Controls.Add($label)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Name = 'progressBar1'
$progressBar.Value = 0
$progressBar.Style="Continuous"
$progressBar.Size = New-Object System.Drawing.Size($ProgressSizeX, $ProgressSizeY)
$progressBar.Left = $ProgressLocationX
$progressBar.Top = $ProgressLocationY

$Form.Controls.Add($progressBar)

$iconBytes = [Convert]::FromBase64String($GLOBAL:ApplicationHemIconBase64)
$stream = New-Object IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
$stream.Write($iconBytes, 0, $iconBytes.Length)
$Form.Icon = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument $stream).GetHIcon())

$Form.Add_Shown({$Form.Activate()})
$Form.Show()| out-null
$Form.Focus() | out-null

<#
$i = 0
while ($i -lt 5){
    [int]$pct = $($i/5)*100
    $progressbar.Value = $pct

    $label.Text="Download in progress... ($NewSize`/$FullSize)"
    $Form.Refresh()
    start-sleep 1
    $i++
}
#>

while($URLFileName -and $FullSize -and -not (Test-Path "$PSScriptRoot`\downloadfinished.txt")){
    $NewSize = $([math]::round($($(Get-Item "$PSScriptRoot`\HPSoftPaqDownloadData`\$URLFileName" -ErrorAction SilentlyContinue).Length / 1Mb), 1))

    [int]$FullSizeInt = $FullSize.split("MB")[0]
    [int]$pct = ($NewSize/$FullSizeInt)*100
    $progressbar.Value = $pct

    $label.Text="Download in progress... ($NewSize`/$FullSize)"
    $Form.Refresh()

    # Do not kick out to lockscreen... Gotta love this workaround I have to do!
    $WShell = New-Object -com "Wscript.Shell"

    $WShell.SendKeys("{SCROLLLOCK}")
    Start-Sleep 1
    $WShell.SendKeys("{SCROLLLOCK}")
}

$Form.Close()

if (Test-Path "$PSScriptRoot`\downloadfinished.txt"){
    Remove-Item "$PSScriptRoot`\downloadfinished.txt" | out-null
}

#All done! Now push UI++ to front...

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class SFW {
 [DllImport("user32.dll")]
 [return: MarshalAs(UnmanagedType.Bool)]
 public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

$fw = (Get-Process -Name 'UI++64').MainWindowHandle
[SFW]::SetForegroundWindow($fw) | out-null
