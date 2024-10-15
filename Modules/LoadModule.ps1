[CmdletBinding()]
param (
    [Parameter()][string[]]$ModuleNames,
    [Parameter()][switch]$Force
)

Set-StrictMode -Version 3.0

$Parent = (Get-PSCallStack)[1]

$LibraryBaseFolder = "$PSScriptRoot"

$ModulePrefix = "ScriptTools"

function LoadModule01 {
    param (
        [Parameter(Mandatory = $true)][string]$ModuleName
    )ModuleName

    $ChildPath = $ModuleName.Replace(".", "\")
    
    $LibraryPath = (Join-Path $LibraryBaseFolder $ChildPath) | Resolve-Path

    if (-not (Test-Path -Path $LibraryPath)) {
        Write-Host "Library $ModuleName not found." -ForegroundColor DarkYellow
        return
    }
    
    $items = Get-ChildItem -Path $LibraryPath -Filter "*.ps1"

    foreach ($item in $items) {
        Write-Verbose "Importing $($item.FullName)"
        $script = Get-Content $item.FullName
        $script = $script -replace '^function\s+((?!global[:]|local[:]|script[:]|private[:])[\w-]+)', 'function Global:$1'
        $script = $script -replace '\$PSScriptRoot', "$LibraryBaseFolder"
        $ofs = "`r`n"
        . ([scriptblock]::Create($script))

        #. $item.FullName
    }
    Write-Host "Library $LibraryName loaded successfully." -ForegroundColor DarkGreen
}

function LoadModule02 {
    param (
        [Parameter(Mandatory = $true)][string]$ModuleName
    )

    $ModuleFullName = "$ModulePrefix.$ModuleName"

    $verbose = $VerbosePreference -ne 'SilentlyContinue'

    if (Get-Module | Where-Object { $_.Name -ieq "$ModuleFullName" }) {
        if ($verbose) {
            Write-Verbose "Module $ModuleFullName already exist!"
        }
        return
    }
    Write-Host "Loading module $ModuleFullName" -ForegroundColor DarkGreen
    $ChildPath = $ModuleName.Replace(".", "\")
    
    $LibraryPath = (Join-Path $LibraryBaseFolder $ChildPath) | Resolve-Path

    $items = Get-ChildItem -Path "$LibraryPath" -Filter "*.ps1"

    $script = "Set-StrictMode -Version 3.0" + [System.Environment]::NewLine

    foreach ($item in $items) {
        if ($item.FullName -ine $Parent.ScriptName) {
            $script = $script + ". $($item.FullName)" + [System.Environment]::NewLine
            if ($verbose) {
                Write-Verbose $item.FullName
            }
        }
        else {
            if ($verbose) {
                Write-Host "$item.FullName not loaded. Recursive call." -ForegroundColor Red
            }
        }

    }
    
    $ofs = "`r`n"
    $sb = [ScriptBlock]::Create($script)
    $arguments = @{
        ScriptBlock = $sb
        Name        = $ModuleFullName
    }
    $module = New-Module @arguments
    Import-Module $module -Scope Global -Force -DisableNameChecking
}

function LmGetLocalizedResourceName {
    param (
        [Parameter()][string] $ResourceName
    )

    $jsonConfigPath = (Join-Path "$PSScriptRoot" "..\.configs\resx.json") | Resolve-Path -ErrorAction SilentlyContinue

    $ui = Get-UICulture

    $array = $ResourceName.Split('.')

    $jsonConfigString = Get-Content $jsonConfigPath | Out-String

    [hashtable]$objects = ConvertFrom-Json -InputObject $jsonConfigString -AsHashtable -Depth 256

    $pointer = $objects

    for ($i = 0; $i -lt $array.Count; $i++) {
        $_key = $array[$i]
        if ($pointer.ContainsKey($_key)) {
            $pointer = $pointer[$_key]
        }
    }
    
    if($pointer -eq $objects){
        $pointer = $null
    }

    if(-not $pointer.ContainsKey($ui.Name)){
        $pointer = $null
    }

    if(-not $pointer){
        Write-Host "Can't find localized name for recource $ResourceName" -ForegroundColor DarkYellow
        return
    }

    return $pointer[$ui.Name]
}

function LmGetObjects {
    param (
        [Parameter()][string]$ConfigName
    )

    $array = $ConfigName.Split('.')
    $jsonConfigPath = (Join-Path "$PSScriptRoot" "..\.configs\$($array[0]).json") | Resolve-Path -ErrorAction SilentlyContinue

    if ((-not $jsonConfigPath) -or -not (Test-Path $jsonConfigPath)) {
        Write-Host "Cinfig $ConfigName not found." -ForegroundColor DarkRed
        return
    }

    $array = $array[1..($array.length - 1)]

    $jsonConfigString = Get-Content $jsonConfigPath | Out-String

    
    [hashtable]$objects = ConvertFrom-Json -InputObject $jsonConfigString -AsHashtable -Depth 256

    $object = $objects

    for ($i = 0; $i -lt $array.Count; $i++) {
        $_key = $array[$i]
        if ($object.ContainsKey($_key)) {
            $object = $object[$_key]
        }

    }

    # if (-not $object) {
    #     foreach ($key in $objects.Keys) {
    #         $value = $objects[$key]
    #         if ($value.Default) {
    #             $object = $value
    #         }
    #     }
    # }

    return $object
}

function LmGetParams {
    param (
        [Parameter(Mandatory = $true)] [hashtable]$InvParams,
        [Parameter(Mandatory = $true)] [hashtable]$PSBoundParams
    )
    $params = $null
    foreach ($h in $InvParams.GetEnumerator()) {
        try {
            $key = $h.Key
            $val = Get-Variable -Name $key -ErrorAction Stop | Select-Object -ExpandProperty Value -ErrorAction Stop
            if (([String]::IsNullOrEmpty($val) -and (!$PSBoundParams.ContainsKey($key)))) {
                throw "A blank value that wasn't supplied by the user."
            }
            Write-Verbose "$key => '$val'"
            if (-not $params) {
                $params = @{}
            }
            $params[$key] = $val
        }
        catch {}
    }
    return $params
}

function TestFunction {
    param (
        [Parameter(Mandatory = $true)] [string]$Name
    )
    Test-Path -Path "function:${Name}"
}

function SortHashtable {
    param (
        [Parameter()][hashtable]$InputHashtable
    )
    $_shash = [System.Collections.Specialized.OrderedDictionary]@{}

    foreach ($key in $InputHashtable.Keys | Sort-Object) {
        $_object = $InputHashtable[$key]
        if ($_object -is [hashtable]) {
            $_object = SortHashtable -InputHashtable $_object
        }
        $_shash[$key] = $_object
    }
    return $_shash
}

function LoadModule {
    param (
        [Parameter()][string[]]$ModuleNames,
        [Parameter()][switch]$Force
    )
    if ($Force) {
        Remove-Module "$ModulePrefix.*"
    }
    foreach ($ModuleName in $ModuleNames) {
        LoadModule02 -ModuleName $ModuleName
    }
}


$params = LmGetParams -InvParams $MyInvocation.MyCommand.Parameters -PSBoundParams $PSBoundParameters
if ($params) {
    LoadModule @params
}