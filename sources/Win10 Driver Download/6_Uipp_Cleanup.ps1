. "$PSScriptRoot`\functions.ps1"

$ItemsToDelete = @(
    "$PSScriptRoot`\HPSoftPaqDownloadData"
    "$PSScriptRoot`\downloadfinished.txt"
    "$PSScriptRoot`\hp_reference.ps1"
    "$PSScriptRoot`\modelchoice.txt"
    "$PSScriptRoot`\UI++2.xml"
)

$ItemsToDelete |% {
    $_item = $_

    if (Test-Path $_item){
        if (Get-IsFolder $_item){
            Remove-Item $_item -Recurse -Confirm:$false -Force -ErrorAction SilentlyContinue
        }
        else{
            try{
                Remove-Item $_item -Confirm:$false -Force -ErrorAction Stop
            }
            catch{
                Run-CMDAndGetOutput "del `"$_item`" /q /f"
            }
        }
    }
}
