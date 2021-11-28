while (-not (Test-Path "$PSScriptRoot`\unpack_finished.txt")){
    $WShell = New-Object -com "Wscript.Shell"
    $WShell.SendKeys("{SCROLLLOCK}")
    Start-Sleep 1
    $WShell.SendKeys("{SCROLLLOCK}")
    Start-Sleep 1
}

Remove-Item "$PSScriptRoot`\unpack_finished.txt" -Force | out-null