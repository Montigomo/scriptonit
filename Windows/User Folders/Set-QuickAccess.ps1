﻿###################
# Set-QuickAccess #
###################
#Version: 2017-08-10.01
#Author: johan.carlsson@innovatum.se

<#

.SYNOPSIS
Pin or Unpin folders to/from Quick Access in File Explorer.

.DESCRIPTION
Pin or Unpin folders to/from Quick Access in File Explorer.

.EXAMPLE
.\Set-QuickAccess.ps1 -Action Pin -Path "\\server\share\redirected_folders\$env:USERNAME\Links"
Pin the specified UNC server share to Quick Access in File Explorer.

.EXAMPLE
.\Set-QuickAccess.ps1 -Action Unpin -Path "\\server\share\redirected_folders\$env:USERNAME\Links"
Unpin the specified UNC server share from Quick Access in File Explorer.

.NOTES
Thanks to the below sources for inspiration :)
https://blogs.technet.microsoft.com/heyscriptingguy/2013/04/26/use-powershell-to-work-with-windows-explorer/
https://www.reddit.com/r/sysadmin/comments/6g5hz4/removing_pinned_quick_access_pins_via_powershell/

.LINK
https://gallery.technet.microsoft.com/Set-QuickAccess-117e9a89

#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true,Position=1,HelpMessage="Pin or Unpin folder to/from Quick Access in File Explorer.")]
    [ValidateSet("Pin", "Unpin")]
    [string]$Action,
    [Parameter(Mandatory=$true,Position=2,HelpMessage="Path to the folder to Pin or Unpin to/from Quick Access in File Explorer.")]
    [string]$Path
)

Write-Host "$Action to/from Quick Access: $Path.. " -NoNewline

#Check if specified path is valid
If ((Test-Path -Path $Path) -ne $true)
    {
        Write-Warning "Path does not exist."
        return
    }
#Check if specified path is a folder
If ((Test-Path -Path $Path -PathType Container) -ne $true)
    {
        Write-Warning "Path is not a folder."
        return
    }

#Pin or Unpin
$QuickAccess = New-Object -ComObject shell.application
$TargetObject = $QuickAccess.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}").Items() | Where-Object {$_.Path -eq "$Path"}
If ($Action -eq "Pin")
    {
        If ($null -ne $TargetObject)
            {
                Write-Warning "Path is already pinned to Quick Access."
                return
            }
        Else
            {
                $QuickAccess.Namespace("$Path").Self.InvokeVerb(“pintohome”)
            }
    }
ElseIf ($Action -eq "Unpin")
    {
        If ($null -eq $TargetObject)
            {
                Write-Warning "Path is not pinned to Quick Access."
                return
            }
        Else
            {
                $TargetObject.InvokeVerb("unpinfromhome")
            }
    }

Write-Host "Done"