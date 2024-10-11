[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)] [string]$UserName
)

#region Imports
. "$PSScriptRoot\Modules\LoadModule.ps1" -ModuleNames @("Common") -Verbose -Force | Out-Null
#endregion


function SetStartupItems {
    param (
        [Parameter(Mandatory = $false)] [string]$UserName
    )

    $objects = GetConfigObjects -ConfigName "Users.$UserName.StartupItems"

    if (Get-IsAdmin) {
        try {

            foreach ($key in $objects.Keys) {
                if ($objects[$key].prepare) {
                    $itemPath = $objects[$key].Path
                    $itemArgument = $null
                    if ($objects[$key].ContainsKey("Argument")) {
                        $itemArgument = $objects[$key].Argument
                    }
                    Set-StartUp -Name $key -Path $itemPath -Argument $itemArgument
                }
            }
            Start-Sleep -Seconds 3  
        }
        catch {
            WriteLog "Error: $_"
            exit
        }
    
    }
    else {
        Start-Process pwsh  -Verb "RunAs" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ""$PSCommandPath"""
    }
}

$params = ConfigGetParams -InvParams $MyInvocation.MyCommand.Parameters -PSBoundParams $PSBoundParameters
if ($params) {
    Set-StartupItems @params
}