Set-StrictMode -Version 3.0


$npcmf = "D:\tools\software\notepad++\contextMenu\NppShell.dll"

regsvr32 $npcmf

#regsvr32 /U $npcmf