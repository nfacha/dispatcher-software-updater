Name "UpdaterHelper"
Caption "UpdaterHelper -Puchisoft Dispatcher"
OutFile "UpdaterHelper.exe"
!include "WordFunc.nsh" ;aka. String parser ;)
!insertmacro WordFind

SilentInstall silent
RequestExecutionLevel admin

var allparams
var cmdType
var updaterDir
var updaterParam
var newUpdaterVer


;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Main section
Section
 Call GetParameters
 pop $allparams
 ${WordFind} $allparams "¤" "+1" $cmdType
 ${WordFind} $allparams "¤" "+2" $updaterDir ;all cmds have it
 
 call ensureWeHaveAdminRights ;Only on XP are you allowed to try to run an Admin-needing program as User
 
 strcmp $cmdType "runUpdater" 0 +3
   call runUpdater
   quit
 strcmp $cmdType "updateUpdater" 0 +3
   call updateUpdater
   quit
   
 messagebox mb_ok "$cmdType ?"
 
SectionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function ensureWeHaveAdminRights
ClearErrors ;Check for Write Access  
  FileOpen $0 "$updaterDir\UpdaterTmpUH.tmp" w
  iferrors 0 admin
    exec '"$updaterDir\Updater.exe" -needadmin' ;Show a nice Need Admin to do this failure with proper Updater title, and dev handled failure (like run dev's software if he wants)
    quit    
 admin:
  FileClose $0
  delete "$updaterDir\UpdaterTmpUH.tmp"
FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function runUpdater
  ${WordFind} $allparams "¤" "+3" $updaterParam
  exec '"$updaterDir\Updater.exe" $updaterParam'
FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function updateUpdater  
  ${WordFind} $allparams "¤" "+3" $newUpdaterVer
  
  ;execshell open $EXEDIR
  ;messagebox mb_ok '"$EXEDIR\UpdaterNew.exe" "$updaterDir\UpdaterNew.exe"'  
  
retryUpdaterCopy:
  clearerrors  
  copyfiles /SILENT /FILESONLY "$EXEDIR\UpdaterNew.exe" "$updaterDir\UpdaterNew.exe"
  iferrors 0 +3
   messagebox mb_retrycancel "Can't update Updater. No write access to $updaterDir?" IDRETRY retryUpdaterCopy
   quit
  
  ;new updater stamp is only put in the right place on a successful updater update (put in tmp until then)
  WriteINIStr "$updaterDir\Updater.dat" "Tmp" "UpdaterStampTmp" $newUpdaterVer  
  exec "$updaterDir\UpdaterNew.exe"  
  quit
FunctionEnd


;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;
Function GetParameters

   Push $R0
   Push $R1
   Push $R2
   Push $R3

   StrCpy $R2 1
   StrLen $R3 $CMDLINE

   ;Check for quote or space
   StrCpy $R0 $CMDLINE $R2
   StrCmp $R0 '"' 0 +3
     StrCpy $R1 '"'
     Goto loop
   StrCpy $R1 " "

   loop:
     IntOp $R2 $R2 + 1
     StrCpy $R0 $CMDLINE 1 $R2
     StrCmp $R0 $R1 get
     StrCmp $R2 $R3 get
     Goto loop

   get:
     IntOp $R2 $R2 + 1
     StrCpy $R0 $CMDLINE 1 $R2
     StrCmp $R0 " " get
     StrCpy $R0 $CMDLINE "" $R2

   Pop $R3
   Pop $R2
   Pop $R1
   Exch $R0

 FunctionEnd