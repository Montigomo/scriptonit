[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)][switch]$TurnOff
)

#region HELP
# SMB: настройка общей сетевой папки в Windows
# https://hackware.ru/?p=10923
# Windows: общие административные папки (Admin$, IPC$, C$)
# https://winitpro.ru/index.php/2016/07/06/kak-vklyuchit-udalennyj-dostup-k-administrativnym-sharam-v-windows-10/
# Windows: разрешить анонимный доступ к общим папкам и принтерам без пароля
# https://winitpro.ru/index.php/2019/03/27/anonimnyj-dostup-k-setevym-papkam-i-printeram/
#endregion

# reset logged sessions info
#Get-Service "LanmanWorkstation" | Restart-Service -Force


#1.
#Get-WindowsCapability -Online -Name Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0

# parameter|turnOnValue|turnOffValue
#01. Accounts: Guest Account Status set Enabled
$result = net user guest
$result = ($result | Where-Object { $_ -imatch "^account active" } ) -split "\ +", 0, "regexmatch"
$guestEnabled = $result[2] -ieq 'yes'

if ($TurnOff) {
    net user guest /active:no
}
else {
    net user guest /active:no
}

#02. Network access: Let Everyone permissions apply to anonymous users|Enabled
# MACHINE\System\CurrentControlSet\Control\Lsa\EveryoneIncludesAnonymous
if ($TurnOff) {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'EveryoneIncludesAnonymous' -Type DWord -Value '0'
}
else {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'EveryoneIncludesAnonymous' -Type DWord -Value '1'
}

#03. Network access: Do not allow anonymous enumeration of SAM accounts and shares|Disabled
# MACHINE\System\CurrentControlSet\Control\Lsa\RestrictAnonymous
if ($TurnOff) {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'RestrictAnonymous' -Type DWord -Value '1'
}
else {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Lsa' -Name 'RestrictAnonymous' -Type DWord -Value '0'
}

#04 Computer Configuration\Windows Settings\Local Policies\User Rights Assignment:Deny log on locally


#Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'RestrictNullSessAccess' -Value '0'

#Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'everyoneincludesanonymous' -Value '1'