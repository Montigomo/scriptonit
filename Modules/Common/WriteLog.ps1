Set-StrictMode -Version 3.0

if(-not (Get-Variable -Name "LogFile" -ErrorAction SilentlyContinue)){
    $Logfile = "$PSScriptRoot\$([System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)).log"
}

if(-not (Get-Command "WriteLog" -ErrorAction SilentlyContinue)){
    function WriteLog {
        Param (
          [Parameter(Mandatory=$false)] [string]$LogString,
          [Parameter(Mandatory=$false)] [switch]$WithoutFunctionName
        )
        $Stamp = Get-Date -Format "yyyy.MM.dd HH:mm:ss"
        if (-not $WithoutFunctionName) {
          $LogString = "[$((Get-PSCallStack)[1].Command)]: $LogString"
        }  
        Write-Host $LogString -ForegroundColor DarkYellow
        $LogString = "$Stamp $LogString"  
        Add-content $LogFile -value $LogString
      }
}