


#region sshd functions version 0.00.04


#region Data

$stringJson = @"
{
  "AuthorizedKeysFile": {
    "order": "00",
    "type": "leaf",
    "value": ".ssh/authorized_keys"},
  "PasswordAuthentication": {
    "order": "00",
    "type": "leaf",
    "value": "no"},
  "PubkeyAuthentication": {
    "order": "00",
    "type": "leaf",
    "value": "yes"},
  "StrictModes": {
    "order": "00",
    "type": "leaf",
    "value": "no"},
  "Subsystem powershell": {
    "order": "00",
    "type": "leaf",
    "value": "pwsh.exe -sshs -NoLogo -NoProfile"},
  "Subsystem sftp": {
    "order": "00",
    "type": "leaf",
    "value": "sftp-server.exe"},
  "Match Group administrators": {
    "order": "90",
    "type": "branch",
    "value": {
      "AuthorizedKeysFile": {
        "order": "00",
        "type": "leaf",
        "value": "__PROGRAMDATA__/ssh/administrators_authorized_keys"
      }
    }
  },
  "Match User anoncvs": {
    "order": "90",
    "type": "branch",
    "value": {
      "AllowTcpForwarding": {
        "order": "00",
        "type": "leaf",
        "value": "no"
      },
      "ForceCommand": {
        "order": "00",
        "type": "leaf",
        "value": "cvs server"
      },
      "PermitTTY": {
        "order": "00",
        "type": "leaf",
        "value": "no"
      }
    }
  }  
}
"@
#endregion

function ConvertPSObjectToHashtable ([object]$InputObject) {
    if ($null -eq $InputObject) { 
        return $null 
    }
    if ($InputObject -is [Hashtable] -or $InputObject.GetType().Name -eq 'OrderedDictionary') {
        return $InputObject 
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $collection = @(
            foreach ($object in $InputObject) { ConvertPSObjectToHashtable($object) }
        )
        return $collection
    }
    elseif ($InputObject -is [psobject]) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $_ht = ConvertPSObjectToHashtable($property.Value)
            if ($_ht -is [hashtable]) {
                #$_ht = SortHashtableSshd -InputHashtable $_ht
            }
            $hash[$property.Name] = $_ht
        }
        return $hash
    }
    else {
        return $InputObject
    }
}

function SortHashtableSshd {
    param (
        [Parameter()][hashtable]$InputHashtable
    )
    $_shash = [System.Collections.Specialized.OrderedDictionary]@{}
    $_obj = @($InputHashtable.GetEnumerator() |  Sort-Object {
            #Write-Host "$_.Key  $_.Value.gettype()"
            if (($_.Value -is [hashtable]) -and $_.Value.ContainsKey("order")) {
                $_.Value.order
            }
            elseif (($_.Value -is [System.Collections.Specialized.OrderedDictionary]) -and $_.Value.Keys.Contains("order")) {
                $_.Value.order
            }
            else {
                "00"
            } , $_.Key
        })

    for ($i = 0; $i -lt $_obj.length; $i++) {
        $key = ($_obj[$i]).Key
        $value = ($_obj[$i]).Value
        if ($value -is [hashtable]) {
            $value = SortHashtableSshd -InputHashtable $value
        }        
        $_shash[$key] = $value
    }

    return $_shash
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

function JsonStringToHashtable {
    param (
        [Parameter()][string]$JsonString
    )
    $hashtable = [hashtable]::new()
    $jsonObject = ConvertFrom-Json $JsonString
    $hashtable = ConvertPSObjectToHashtable -InputObject $jsonObject
    return $hashtable
}

#region ConvertJsonToSshdConfig ConvertSshdConfigToJson

function HashToSshdConfig {
    param (
        [Parameter()][hashtable]$InputHashtable,
        [Parameter()][string]$Indent = ""
    )
    $hash = SortHashtableSshd -InputHashtable $InputHashtable
    $outputString = ""
    foreach ($key in $hash.Keys) {
        $value = $hash.$key.value
        if (($value -is [hashtable]) -or ($value -is [System.Collections.Specialized.OrderedDictionary])) {
            $outputString = $outputString + "$key$([System.Environment]::NewLine)"
            $value = HashToSshdConfig -InputHashtable $value -Indent "  "
            $outputString = $outputString + "$value$([System.Environment]::NewLine)"
        }
        else {
            $outputString = $outputString + "$Indent$key $value$([System.Environment]::NewLine)"
        }
    }
    $outputString = $outputString.TrimEnd([System.Environment]::NewLine)
    return $outputString
}

function ConvertJsonToSshdConfig {
    param (
        [Parameter()][string]$JsonString
    )
    $hash = JsonStringToHashtable $JsonString
    #$hash = SortHashtableSshd -InputHashtable $hash
    $outputString = HashToSshdConfig -InputHashtable $hash
    return $outputString
}

function ConvertSshdConfigToJson {
    param (
        [Parameter()][string]$FilePath
    )
    $items = Get-Content -Path $FilePath -Encoding utf8
    $_hash = [hashtable]::new()
    $currentNode = $_hash
    #$parsing_error = $false
    foreach ($item in $items) {
        if (-not ($item -match "^\s*#")) {
            $re = "^\s*(?<param>\S+)\s+(?<value>[^\n]*)"
            if ($item -match $re) {
                $param = $Matches["param"]
                $value = $Matches["value"]

                switch ($param) {
                    "subsystem" {
                        $ress = "^(?<value01>\S+)\s+(?<value02>[^\n]+)"
                        if ($value -match $ress) {
                            $value01 = $Matches["value01"]
                            $value02 = $Matches["value02"]
                            #Write-Host "value01: $value01; value02: $value02"
                            $param = "$param $value01"
                            $value = $value02
                        }
                        else {
                            throw "ssh config parsing error"
                        }
                        $_htv = @{
                            "value" = $value
                            "order" = "00"
                            "type"  = "leaf"
                        }
                        $currentNode.Add($param, $_htv)
                        break;
                    }
                    "match" {
                        $currentNode = $_hash
                        $ress = "^(?<value01>\S+)\s+(?<value02>[^\n]+)"
                        if ($value -match $ress) {
                            $value01 = $Matches["value01"]
                            $value02 = $Matches["value02"]
                            #Write-Host "value01: $value01; value02: $value02"
                            $param = "$param $value01 $value02"
                            $value = ""
                            $_htv = @{
                                "value" = $value
                                "order" = "90"
                                "type"  = "branch"
                            }
                            $currentNode.Add($param, $_htv)
                            $currentNode[$param]["value"] = [hashtable]::new()
                            $currentNode = $currentNode[$param]["value"]
                        }
                        else {
                            throw "ssh config parsing error"
                        }
                        break;
                    }
                    default {
                        $_htv = @{
                            "value" = $value
                            "order" = "00"
                            "type"  = "leaf"
                        }
                        $currentNode.Add($param, $_htv)
                        break;
                    }
                }

            }
        }
    }
    $_hash = SortHashtableSshd -InputHashtable $_hash
    return ($_hash | ConvertTo-Json -Depth 10)
}

#endregion

function CompareSshdConfig {
    param (
        [Parameter()][string]$FilePath,
        [Parameter()][string]$JsonString
    )

    $result = $false

    $_fileJson = ConvertSshdConfigToJson -FilePath $FilePath

    $hash = JsonStringToHashtable -JsonString $JsonString
    $hash = SortHashtableSshd -InputHashtable $hash
    $_stringJson = $hash | ConvertTo-Json -Depth 10

    # method 1
    # $json01 = $hash | ConvertTo-Json -Depth 10 -Compress
    # $json02 = ($_stringJson | ConvertFrom-Json | ConvertTo-Json -Depth 10 -Compress)
    # $result = ($json01 -ieq $json02)

    # method 2
    $obj01 = ($_fileJson -split '\r?\n')
    $obj02 = ($_stringJson -split '\r?\n')
    $result = Compare-Object $obj01 $obj02
    $result = -not $result

    return $result
}

function WriteSshdConfig {
    param (
        [Parameter()][string]$FilePath,
        [Parameter()][string]$JsonString
    )
    $string = ConvertJsonToSshdConfig -JsonString $JsonString
    $string | Out-File -FilePath $FilePath  -Encoding utf8
}


function CheckSshdConfig {
    param (
        [Parameter()][string]$SshdConfigPath,
        [Parameter()][string]$OutFile,
        [Parameter()][string]$JsonString
    )
    
    $result = CompareSshdConfig -FilePath $SshdConfigPath -JsonString $JsonString

    if (-not $result) {
        WriteSshdConfig -FilePath $OutFile -JsonString $JsonString
    }
}

function CheckSshdService {

    $result = $true

    for ($i = 0; $i -lt 5; $i++) {
        if ((Get-Service sshd).Status -ine "running") {
            $result = $false
            break
        }
        Start-Sleep -Seconds 1
    }
    return $result
}

function CheckSshd {
    param (
        [Parameter()][string]$SshdConfigPath,
        [Parameter()][string]$JsonString
    )
    if (-not (CheckSshdService)) {
        SshdServices -Action Stop
        WriteSshdConfig -FilePath $SshdConfigPath -JsonString $JsonString
        SshdServices -Action Start
    }
}

enum ServiceAction {
    Start
    Stop
    Restart
}

function SshdServices {
    param (
        [Parameter()][ServiceAction]$Action
    )
    
    $services = @("sshd", "ssh-agent")
    switch ($Action) {
        Restart{
            foreach ($serviceName in $services) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    $service | Restart-Service
                }
            }
            break
        }
        Stop{
            foreach ($serviceName in $services) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    $service | Stop-Service -ErrorAction SilentlyContinue
                }
            }            
            break
        }
        Start {
            foreach ($serviceName in $services) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    $service | Set-Service -StartupType 'Automatic' | Start-Service
                }
            }
        }
    }
}

#endregion


#$sshConfigFile = "$env:ProgramData/ssh/sshd_config"

#$SrcFile = "$PSScriptRoot\sshd_config" 

#$OutFile = "$PSScriptRoot\sshd_config_test"

#$result = ConvertSshdConfigToJson -FilePath "$PSScriptRoot\sshd_config_full_utf16.txt"

#$result = CompareSshdConfig -FilePath $SrcFile -JsonString $stringJson

#CheckSshdConfig -SrcFile $SrcFile -OutFile $OutFile -JsonString $stringJson

#CheckSshd -FilePath "$env:ProgramData/ssh/sshd_config" -JsonString $stringJson
