Set-StrictMode -Version 3.0

function LoadModules {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$Folder
    )
    $items = Get-ChildItem -Path $Folder -Directory | Where-Object { $_.Name -match "^Agt\..?" }
    foreach ($item in $items) {
        Import-Module -Name $item.FullName
    }
}



Get-Module | Where-Object { $_.Name -ilike "*agt*" } | Remove-Module

LoadModules -Folder "D:\work\powershell\PwshScripts\Modules"

Add-Host -HostIp 127.0.0.1 -HostName "iws.corel.com"

#New-NetFirewallRule -DisplayName "Allow Deluge" -Direction Inbound -Program "C:\Program Files (x86)\Deluge\deluge.exe" -Action allow
#%ProgramFiles%\Corel\CorelDRAW Graphics Suite 2022\Programs64\CorelDRW.exe
New-NetFirewallRule -Program "C:\Program Files\Corel\CorelDRAW Graphics Suite 2022\Programs64\CorelDRW.exe" -Action Block -Profile Any -DisplayName “Block CorelDRW” -Description “Block CorelDRW” -Direction Outbound

# ccleaner app
Add-Host -HostIp 127.0.0.1 -HostName "license-api.ccleaner.com"