Set-StrictMode -Version 3.0

function GetGitHubApiUri{
    param(
        [Parameter(Mandatory = $true)] [string]$GitProjectUrl
    )
    
    [uri]$_gitProjectUri = $null
    [uri]$_gitProjectApiUri = $null

    if($Deep -lt 1){
        $Deep = 1
    }
    
    if (-not([uri]::TryCreate($GitProjectUrl, [UriKind]::Absolute, [ref]$_gitProjectApiUri))) {
        return
    }

    $uriBuilder = [System.UriBuilder]::new($_gitProjectApiUri)
    if (($uriBuilder.Host -ieq "github.com") -and (-not $uriBuilder.Path.StartsWith("/repos"))) {
        $_gitProjectUri = $uriBuilder.Uri
        $uriBuilder.Host = "api.github.com"
        $uriBuilder.Path = "/repos$($uriBuilder.Path)"
        $_gitProjectApiUri = $uriBuilder.Uri
    }
    elseif (($uriBuilder.Host -ieq "api.github.com") -and ($uriBuilder.Path.StartsWith("/repos"))) {
        $_gitProjectApiUri = $uriBuilder.Uri
        $uriBuilder.Host = "github.com"
        $uriBuilder.Path = ($uriBuilder.Path -replace "^/repos", "")
        $_gitProjectUri = $uriBuilder.Uri
    }
    else {
        Write-Host "Wrong url - $GitProjectUrl" -ForegroundColor DarkYellow
        return
    }

    return $_gitProjectApiUri
}

function GetGitHubItems {
    param(
        [Parameter(Mandatory = $true)] [string]$Uri,
        [Parameter(Mandatory = $false)] [string]$ReleasePattern,
        [Parameter(Mandatory = $false)] [string[]]$VersionPattern,
        [Parameter(Mandatory = $false)] [int]$Deep = 1,
        [Parameter(Mandatory = $false)] [switch]$UsePreview
    )

    $Uri = "$Uri/releases" -replace "(?<!:)/{2,}", "/"
    $json = (Invoke-RestMethod -Method Get -Uri $Uri)
    $objects = $json | Where-Object { (-not $_.prerelease) -or ($UsePreview -and $_.prerelease) } | Sort-Object -Property published_at -Descending
    $objects = $objects | Select-Object -First $Deep
    $_remoteVersion = [System.Version]::Parse("0.0.0")
    $_objects = @{}

    foreach ($object in $objects) {
        $vpresult = $false
        $vstring = $object.tag_name

        if ($VersionPattern) {
            if ($vstring -match $VersionPattern) {
                $vpresult = [System.Version]::TryParse($Matches["version"], [ref]$_remoteVersion)
            }        
        }
    
        if (-not $vpresult) {
            switch -Regex ($vstring) {
                "(?<v1>\d?\d\.\d\d?)-beta(?<v2>\d\d?)" {
                    $vpresult = [System.Version]::TryParse("$($Matches["v1"]).$($Matches["v2"])", [ref]$_remoteVersion)
                    break 
                }            
                "v?(?<version>\d?\d\.\d?\d\.?\d?\d?\.?\d?\d?)" { 
                    $vpresult = [System.Version]::TryParse($Matches["version"], [ref]$_remoteVersion)
                    break 
                }

            }
        }

        if (-not $vpresult) {
            throw "Can't parse version info."
        }

        $assets = @{}

        if ($ReleasePattern) {
            $assets = $object.assets | Where-Object name -match $ReleasePattern | Select-Object -ExpandProperty 'browser_download_url'
        }
        else {
            $assets = $object.assets | Select-Object -ExpandProperty 'browser_download_url'
        }
        $_objects.Add($_remoteVersion, $assets)
    }
    return $_objects
}


function DownloadGitHubItems {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string]$GitProjectUrl,
        [Parameter(Mandatory = $true)] [string]$DestinationFolder,
        [Parameter(Mandatory = $false)] [int]$Deep = 1,
        [Parameter(Mandatory = $false)] [switch]$UsePreview,
        [Parameter(Mandatory = $false)] [switch]$Force
    )
    
    [uri]$_gitProjectApiUri = GetGitHubApiUri -GitProjectUrl $GitProjectUrl

    $objects = GetGitHubItems -Uri $_gitProjectApiUri -UsePreview:$UsePreview -Deep $Deep

    foreach ($object in $objects.GetEnumerator()) {

        $_destinationFolder = Join-Path $DestinationFolder $object.Key

        if (-not (Test-Path -PathType Container $_destinationFolder)) {
            New-Item -ItemType Directory -Path $_destinationFolder | Out-Null
        }

        Write-Host "Project $($_gitProjectUri.AbsoluteUri);  Version $($object.Key); Destination folder: $_destinationFolder" -ForegroundColor DarkYellow
        
        foreach ($value in $object.Value) {


            [uri]$uri = $null
            if ([uri]::TryCreate($value, [UriKind]::Absolute, [ref]$uri)) {
                $_fileName = $uri.Segments[$uri.Segments.Count - 1]
                $_destinationPath = Join-Path $_destinationFolder $_fileName
                if ((-not (Test-Path $_destinationPath)) -or $Force) {
                    Write-Host "Writing file $_fileName" -ForegroundColor DarkYellow
                    Invoke-WebRequest -Uri $value -OutFile $_destinationPath
                }
                else {
                    Write-Host "File $_fileName exist, skipping." -ForegroundColor DarkGray
                }
            }
        }
    }
}