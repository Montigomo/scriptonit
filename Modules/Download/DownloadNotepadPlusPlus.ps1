Set-StrictMode -Version 3.0


. "$PSScriptRoot\..\LoadModule.ps1" -ModuleNames @("Common") | Out-Null

function DownloadNotepadPlusPlus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)] [string]$DestinationFolder = "D:\_software\network\VirtualHere"
    )

    Get-ModuleAdvanced -ModuleName "PowerHTML"

    #region variables

    $urlDownload = "https://notepad-plus-plus.org/downloads/"

    #endregion

    #region Get-ModuleAdvanced
    if (-not (Get-Command "Get-ModuleAdvanced" -ErrorAction SilentlyContinue)) {
        Write-Host "Can't find function with name 'Get-ModuleAdvanced'" -ForegroundColor DarkYellow
        return
    }
    #endregion

    $htmlDoc = ConvertFrom-Html -URI $urlDownload
    
    $nodes = $htmlDoc.SelectNodes('/html/body/div[1]/div/div/main[@id="main"]/ul/li')

    if ((-not $nodes)) {
        Write-Host "Error parsing html content." -ForegroundColor DarkYellow
        exit
    }

    foreach($node in $nodes){
        
    }

    #GetServer -DestinationFolder $DestinationFolder

    #GetClient -DestinationFolder $DestinationFolder
}
