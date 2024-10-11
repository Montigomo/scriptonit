Set-StrictMode -Version 3.0


#region Imports
. "$PSScriptRoot\..\LoadModule.ps1" -ModuleNames @("Common") | Out-Null
#endregion
    
#region functions
function DownloadFiles {
    param (
        [Parameter(Mandatory = $true)] [System.Uri[]] $UrlArray,
        [Parameter(Mandatory = $true)] [string] $DestinationFolder
    )
    if (-not(Test-Path $DestinationFolder -PathType Container)) {
        New-Item -Path $DestinationFolder -ItemType Directory | Out-Null
    }
    foreach ($url in $UrlArray) {
        $fileName = $url.Segments[$url.Segments.Length - 1]
        $filePath = [System.IO.Path]::Combine($DestinationFolder, $fileName)
        if (Test-Path $filePath) {
            Write-Host "File $filePath already exist." -ForegroundColor DarkYellow
        }
        Write-Host "Downloading $fileName" -ForegroundColor Yellow
        try {
            $response = Invoke-WebRequest -Uri $url -OutFile $filePath
            #Write-Host "Response $($response.StatusCode)" -ForegroundColor Green
        }
        catch {
            Write-Host "Response $($response.StatusCode)" -ForegroundColor Green
        }
        if (-not (Test-Path $filePath)) {
            Write-Host "Error when downloading $($url.AbsoluteUri)"
        }
    }
    
}

function GetFiles1 {
    param (
        [Parameter()][string]$XPath,
        [Parameter(Mandatory = $true)] [string] $DestinationFolder
    )
    $node = $htmlDoc.SelectSingleNode($XPath)
    $nodes = $node.SelectNodes('.//li/a')
    if ($nodes.Count -lt 1) {
        Write-Host "Can't get urls" -ForegroundColor DarkYellow
        return
    }
    $urlArray = @()
    foreach ($node in $nodes) {
        $url = [string]$node.Attributes["href"].Value
        if (-not $url.StartsWith("http")) {
            $urlArray += [System.Uri]"$urlHost$url"
        }
    }
    #$urlArray = $nodes | ForEach-Object { [System.Uri]"$urlHost$($_.Attributes["href"].Value)" }
    DownloadFiles -UrlArray $urlArray -DestinationFolder $DestinationFolder
}

function GetFiles2 {
    param (
        [Parameter()][string]$XPath,
        [Parameter(Mandatory = $true)] [string] $DestinationFolder
    )
    $node = $htmlDoc.SelectSingleNode($XPath)
    $nodes = $node.SelectNodes('.//p/a')
    $nodes = $nodes | Where-Object { [string]$_.Attributes["href"].Value -imatch ".*\/usbclient\/.*" }
    if ($nodes.Count -lt 1) {
        Write-Host "Can't get urls" -ForegroundColor DarkYellow
        return
    }
    $urlArray = @(
        [System.Uri]"https://www.virtualhere.com/sites/default/files/usbclient/SHA1SUM"
    )
    foreach ($node in $nodes) {
        $url = [string]$node.Attributes["href"].Value
        if (-not $url.StartsWith("http")) {
            $urlArray += [System.Uri]"$urlHost$url"
        }
    }

    #$urlArray = $nodes | ForEach-Object { [System.Uri]"$urlHost$($_.Attributes["href"].Value)" }
    DownloadFiles -UrlArray $urlArray -DestinationFolder $DestinationFolder

}
#endregion

function DownLoadDotNet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)] [string]$DestinationFolder
    )


    #region variables

    $url = "https://dotnet.microsoft.com/en-us/download/dotnet-framework"

    #endregion



    #region Get-ModuleAdvanced
    if (-not (Get-Command "Get-ModuleAdvanced" -ErrorAction SilentlyContinue)) {
        Write-Host "Can't find function with name 'Get-ModuleAdvanced'" -ForegroundColor DarkYellow
        return
    }
    #endregion    
    Get-ModuleAdvanced -ModuleName "PowerHTML"


    $htmlDoc = ConvertFrom-Html -URI $url

    $node = $htmlDoc.SelectSingleNode('/html/body/div[4]/div[2]/div[2]')
    #$node = $htmlDoc.SelectSingleNode('//*[@id="supported-versions-table"]')

    if ((-not $node) -or ($node.InnerText -inotmatch "^version\s(?<version>\d\d?\.\d\d?\.\d\d?)")) {
        Write-Host "Error parsing html content." -ForegroundColor DarkYellow
        exit
    }
    $versionTxt = $Matches["version"]
    $serverVersion = [System.Version]::Parse("0.0.0")
    $null = [System.Version]::TryParse($versionTxt, [ref]$serverVersion)

    $DestinationFolder = [System.IO.Path]::Combine($DestinationFolder, "server", $serverVersion.ToString())

}