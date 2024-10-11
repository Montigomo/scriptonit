[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)] [string]$UserName
)

Set-StrictMode -Version 3.0

#region Imports
. "$PSScriptRoot\Modules\LoadModule.ps1" -ModuleNames @("Common", "Common.UserFolders", "Network") -Verbose | Out-Null
#endregion

#region functions
function ConvertFrom-FixedColumnTable {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)] [string] $InputObject
    )
    # Note:
    #  * Accepts input only via the pipeline, either line by line, 
    #    or as a single, multi-line string.
    #  * The input is assumed to have a header line whose column names
    #    mark the start of each field
    #    * Column names are assumed to be *single words* (must not contain spaces).
    #  * The header line is assumed to be followed by a separator line
    #    (its format doesn't matter).
    begin {
        Set-StrictMode -Version 1
        $lineNdx = 0
    }
    
    process {
        $lines = 
        if ($InputObject.Contains("`n")) { $InputObject.TrimEnd("`r", "`n") -split '\r?\n' }
        else { $InputObject }
        foreach ($line in $lines) {
            ++$lineNdx
            if ($lineNdx -eq 1) { 
                # header line
                $headerLine = $line 
            }
            elseif ($lineNdx -eq 2) { 
                # separator line
                # Get the indices where the fields start.
                $fieldStartIndices = [regex]::Matches($headerLine, '\b\S').Index
                # Calculate the field lengths.
                $fieldLengths = foreach ($i in 1..($fieldStartIndices.Count - 1)) { 
                    $fieldStartIndices[$i] - $fieldStartIndices[$i - 1] - 1
                }
                # Get the column names
                $colNames = foreach ($i in 0..($fieldStartIndices.Count - 1)) {
                    if ($i -eq $fieldStartIndices.Count - 1) {
                        $headerLine.Substring($fieldStartIndices[$i]).Trim()
                    }
                    else {
                        $headerLine.Substring($fieldStartIndices[$i], $fieldLengths[$i]).Trim()
                    }
                } 
            }
            else {
                # data line
                $oht = [ordered] @{} # ordered helper hashtable for object constructions.
                $i = 0
                foreach ($colName in $colNames) {
                    $oht[$colName] = 
                    if ($fieldStartIndices[$i] -lt $line.Length) {
                        if ($fieldLengths[$i] -and $fieldStartIndices[$i] + $fieldLengths[$i] -le $line.Length) {
                            $line.Substring($fieldStartIndices[$i], $fieldLengths[$i]).Trim()
                        }
                        else {
                            $line.Substring($fieldStartIndices[$i]).Trim()
                        }
                    }
                    ++$i
                }
                # Convert the helper hashable to an object and output it.
                [pscustomobject] $oht
            }
        }
    }
    
}

function InstallApps {
    param (
        [Parameter(Mandatory = $true)][string]$UserName
    )

    Write-Host "Install apps ..." -ForegroundColor Green; 
    $objects = GetConfigObjects -ConfigName "WinTune.$UserName.Applications"
  
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $arrss = (winget list --accept-source-agreements) -match '^(\p{L}|-)' | ConvertFrom-FixedColumnTable

    foreach ($item in $objects) {
        if (-not ($arrss | Where-Object { $_.Id -ieq $item })) {
            #if ((winget search --id "Microsoft.DotNet.DesktopRuntime" --exact) -match '^(\p{L}|-)' -ine "No package found matching input criteria.") {
            winget install --id "$item" --exact --source winget --silent
        }
    }

}

function InstallMsvcrt {
    Write-Host "Install all Msvcrt ..." -ForegroundColor Green; 
    $items = @(
        "Microsoft.VCRedist.2015+.x86"
        "Microsoft.VCRedist.2015+.x64"
        "Microsoft.VCRedist.2013.x86"
        "Microsoft.VCRedist.2013.x64"
        "Microsoft.VCRedist.2012.x86"
        "Microsoft.VCRedist.2012.x64"
        "Microsoft.VCRedist.2010.x86"
        "Microsoft.VCRedist.2010.x64"
        "Microsoft.VCRedist.2008.x86"
        "Microsoft.VCRedist.2008.x64"
        "Microsoft.VCRedist.2005.x86"  
        "Microsoft.VCRedist.2005.x64"
    )

    foreach ($item in $items) {
        winget install --exact --silent --id $item
    }
}

function AddRegFile {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $RegFilePath
    )
    $startprocessParams = @{
        FilePath     = "$Env:SystemRoot\REGEDIT.exe"
        ArgumentList = '/s', """$RegFilePath"""
        Verb         = 'RunAs'
        PassThru     = $true
        Wait         = $true
    }
    $proc = Start-Process @startprocessParams
    
    # if ($proc.ExitCode -eq 0) {
    #     'Success!'
    # }
    # else {
    #     "Fail! Exit code: $($Proc.ExitCode)"
    # }
}
#endregion

#region Actions

function AddRegFiles {
    param (
        [Parameter(Mandatory = $true)][string]$UserName,
        [Parameter(Mandatory = $false)][string]$Folder = "$PSScriptRoot\Windows\Registry"
    )
 
    $objects = GetConfigObjects -ConfigName "WinTune.$UserName.RegFiles"
  
    foreach ($item in $objects) {
        $filePath = "$Folder{0}" -f $item
        if (Test-Path -Path $filePath) {
            AddRegFile -RegFilePath $filePath
        }
        else {
            Write-Output "$filePath does not exist."
        }
    }

}

function PrepareHostsRaw {
    param (
        [Parameter(Mandatory = $true)] [string[]]$Hosts
    )
    foreach ($item in $Hosts) {
        $values = ($item -split "\|")
        Add-Host -HostIp $values[0] -HostName $values[1]
    }

}

function PrepareHosts {
    param (
        [Parameter(Mandatory = $true)][string]$UserName
    )
    
    $objects = GetConfigObjects -ConfigName "Users.$UserName.Hosts"

    foreach ($key in $objects.Keys) {
        PrepareHostsRaw -Hosts $objects[$key]
    }

}

function SetUserFolders {

    # https://stackoverflow.com/questions/25049875/getting-any-special-folder-path-in-powershell-using-folder-guid/25094236#25094236
    # https://renenyffenegger.ch/notes/Windows/dirs/_known-folders
  
    $userName = [Environment]::UserName

    $baseUserFolders = "D:\_users\{0}" -f $userName

    if (-not ([System.Management.Automation.PSTypeName]'KnownFolder').Type) {
        Write-Host -ForegroundColor DarkYellow "Type [KnownFolder] doesn't exsist."
        return
    }


    $KnownFolders = @{
        "Documents" = @{
            Handle      = $true
            FolderName  = "Personal"
            GUID        = [KnownFolder]::Documents
            ComfortName = "Documents"
            Destination = "$baseUserFolders\Documents"
        };
        "Pictures"  = @{
            Handle      = $true
            FolderName  = "My Pictures"
            GUID        = [KnownFolder]::Pictures
            ComfortName = "Pictures"
            Destination = "$baseUserFolders\Pictures"
        };
        "Desktop"   = @{
            Handle      = $false
            FolderName  = "Desktop"
            GUID        = [KnownFolder]::Desktop
            ComfortName = "Desktop"
            Destination = "$baseUserFolders\Desktop"
        };
        "Video"     = @{
            Handle      = $false
            FolderName  = "My Video"
            GUID        = [KnownFolder]::Videos
            ComfortName = "Videos"
            Destination = "$baseUserFolders\Videos"
        };
        "Music"     = @{
            Handle      = $false
            FolderName  = "My Music"
            GUID        = [KnownFolder]::Music
            ComfortName = "Music"
            Destination = "$baseUserFolders\Music"
        };
    }
    
    function UpdateUserFoldersByReg {
        [CmdletBinding()]
        param (
            [Parameter()][string]$UserProfilesFolder = $env:USERPROFILE
        )
        
        Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" `
            -Name $UserFolderName -Value $UserFolderPath -Type String -Force
        Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" `
            -Name $UserFolderClass -Value $UserFolderPath -Type ExpandString
        Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" `
            -Name $UserFolderName -Value $UserFolderPath -Type ExpandString
    }
    
    foreach ($key in $KnownFolders.Keys) {
        $item = $KnownFolders[$key]
        $handle = $item.Handle
        $FolderName = $item.FolderName
        $GUID = $item.GUID
        $ComfortName = $item.ComfortName
        $Destination = $item.Destination
        $Location = [KnownFolder]::GetKnownFolderPath($GUID)
        Write-Host "Forder " -NoNewline -ForegroundColor DarkYellow
        Write-Host "$FolderName " -NoNewline -ForegroundColor DarkGreen
        Write-Host "preparing. Location - " -NoNewline -ForegroundColor DarkYellow
        Write-Host "$Location. " -NoNewline -ForegroundColor DarkGreen 
        Write-Host "Destination - " -NoNewline -ForegroundColor DarkYellow
        Write-Host "$Destination." -ForegroundColor DarkGreen
        if ($Destination -ine $Location) {
            New-Item -ItemType Directory -Force -Path $Destination | Out-Null
            [KnownFolder]::SetKnownFolderPath($GUID, $Destination)
            $Location = [KnownFolder]::GetKnownFolderPath($GUID)
            if ($Location -ieq $Destination) {
                Write-Host "Folder $FolderName location changed to $Destination" -ForegroundColor DarkGreen
            }
            else {
                Write-Host "Can't change folder $FolderName location to $Destination" -ForegroundColor Red
            }

        }

    }

}

function SetMpPreference {
    param (
        [Parameter(Mandatory = $true)][string]$UserName
    )

    Write-Host "Set MpPreference" -ForegroundColor Green; 
    $objects = GetConfigObjects -ConfigName "Users.$UserName.MpPreference"

    $mp = (Get-MpPreference)
    $o = $mp.ExclusionPath

    foreach ($item in $objects) {
        if ((Test-Path $item) -and ($o -inotcontains $item )) {
            Add-MpPreference -ExclusionPath $item
        }
    }
}

function MakeLinks {
    param (
        [Parameter(Mandatory = $true)][string]$UserName
    )

    $objects = GetConfigObjects -ConfigName "Users.$UserName.SimLinks"

    foreach ($key in $objects.Keys) {
        $itemPath = "$([System.Environment]::GetFolderPath("UserProfile"))$key"
        $itemDstPath = $objects[$key]
        $item = Get-Item "$itemPath" -ErrorAction SilentlyContinue
        if (Test-Path $itemDstPath) {
            if ($item -and (
            ($item.GetType() -ne [System.IO.FileInfo]) -or 
            (-not $item.LinkType) -or 
            (-not ($item.LinkType -eq "SymbolicLink")))) {
                Remove-Item -Path $itemPath -Force -ErrorAction SilentlyContinue

            }
            if (-not (Test-Path -Path $itemPath)) {
                New-Item -Path $itemPath -ItemType SymbolicLink -Value $itemDstPath | Out-Null
            }
        }
    }

}

function SetRdpConnections {
    param(
        [Parameter(Mandatory = $false)][switch]$Disable
    )
    if ($Disable) {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 1
        Disable-NetFirewallRule -DisplayGroup "Remote Desktop"
    }
    else {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    }
}

function GitConfig {
    $array = git config --global --list
    if (-not $($array -icontains "safe.directory=*")) {
        git config --global --add safe.directory "*"
    }
}

function TuneWindows {
    param (
        [Parameter(Mandatory = $true)] [string]$UserName
    )

    InstallMsvcrt
    SetRdpConnections
    GitConfig
    SetUserFolders


    InstallApps  @PSBoundParameters
    SetMpPreference @PSBoundParameters
    PrepareHosts  @PSBoundParameters
    AddRegFiles @PSBoundParameters
    MakeLinks @PSBoundParameters

}

$params = ConfigGetParams -InvParams $MyInvocation.MyCommand.Parameters -PSBoundParams $PSBoundParameters
if ($params) {
    TuneWindows @params
}