Set-StrictMode -Version 3.0

function Get-IsAdmin {  
    $Principal = new-object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    [bool]$Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}