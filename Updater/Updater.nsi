Setcompressor /solid lzma  
!include externalFunctions.nsh
!include WinMessages.nsh
!include "FileFunc.nsh" ;;only for GetTime
!insertmacro GetTime
!include "WordFunc.nsh" ;aka. String parser ;)
!insertmacro WordFind

;;;For Ad
!include nsDialogs.nsh
!include LogicLib.nsh

;;;

!system "MakeDataIncl.exe"
!include "installer_includes.nsh"
!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "DebugBuild"
!endif 
;!ifndef PRODUCT_EDITION ;this is always defined by Installer_Includes now, which gets it from Dispatcher.dat, set by MakeEdition
;  !define PRODUCT_EDITION "Pro" ;Free, Pro, Corp
;!endif

!define UPDATER_HELPER_CUTENAME "Updater.exe" ;UpdaterHelper.exe will be named this EXE name in the AppData/GUID folder


!macro WRITELN LINE ;must use this to print to screen log
SetdetailsPrint listonly ;allow printing details
detailprint "${LINE}"
SetdetailsPrint none ;don't print any details
!macroend
!macro WRITESTATUS LINE ;must use this to change the status (above progress bar)
SetdetailsPrint textonly ;allow printing details
detailprint "${LINE}"
SetdetailsPrint none ;don't print any details
!macroend
!macro OnSomethingDo VARIABLE ;Handles RunClose stuff, that happens OnSomething...like Updates or Fail (If this is skipped, you only lose the close functionality, run still happens later)
   ;MessageBox MB_OK "OnSomethingDo ${VARIABLE}"
   ;strcmp VARIABLE 2 0 +2
     ;Call runUsrProg  ;this macro is called right when things happened, so dont run the userProg yet
   strcmp ${VARIABLE} 3 0 +2 ;Close and Run Program, just run first    
     Call runUsrProg ;last chance, do it       
   strcmp ${VARIABLE} 3 0 +3 ;Close and Run Program, now just close    
     sleep 1000
     Quit
   strcmp ${VARIABLE} 1 0 +3
     sleep 1000
     Quit  
!macroend
!macro AfterOnSomethingDo VARIABLE ;Handles RunClose stuff, that happens OnSomething...like Updates or Fail
   ;MessageBox MB_OK "AfterOnSomethingDo ${VARIABLE}"
   strcmp ${VARIABLE} 2 0 +2
     Call runUsrProg   ;this macro is called when the GUI ends, so run things, but dont bother quitting twice
   strcmp ${VARIABLE} 3 0 +2
     Call runUsrProg                 
!macroend

!macro GETLANGTEXT LANGVAR PARAM1 PARAM2
  ;returns: $resultLangText
  readinistr $resultLangText $updrSettingsFile "Language" "${LANGVAR}"
   strcmp $resultLangText "" 0 +2
    readinistr $resultLangText "$PLUGINSDIR\English.ini" "Language" "${LANGVAR}"
   strcmp $resultLangText "" 0 +2
    strcpy $resultLangText "ERR:${LANGVAR} Not Defined! "
  
  ;always available %%vars
  Push $resultLangText        ;replace
  Push "%%name"               ;this
  Push "$updrSettingsName"    ;with this
  Call StrRep
  Pop "$resultLangText"       ;result
  
  Push $resultLangText        ;replace
  Push "%%newVer"               ;this
  Push "$newStrVer"           ;with this
  Call StrRep
  Pop "$resultLangText"       ;result
  
  Push $resultLangText        ;replace
  Push "%%myVer"               ;this
  Push "$updrSettingsStrVer"   ;with this
  Call StrRep
  Pop "$resultLangText"       ;result 
  
  Push $resultLangText        ;replace
  Push "%%n"                  ;this
  Push "$\n"                  ;with this
  Call StrRep
  Pop "$resultLangText"       ;result
                                       
  ;generic params
  Push $resultLangText ;replace
  Push "%%1"            ;this
  Push "${PARAM1}"            ;with this
  Call StrRep
  Pop "$resultLangText" ;result
  
  Push $resultLangText ;replace
  Push "%%2"            ;this
  Push "${PARAM2}"            ;with this
  Call StrRep
  Pop "$resultLangText" ;result  
  
  Push $resultLangText ;replace
  Push "%%errorCode"            ;this
  Push "${__LINE__}"            ;with this
  Call StrRep
  Pop "$resultLangText" ;result  
  
!macroend


;Puchisoft Updater (For Dispatcher)
Name "Puchisoft Updater"
OutFile "..\Data\Updater.exe"
;OutFile "Updater.exe"
;Caption "$updrSettingsName Updater $bFullRecoverTitleStr- [Puchisoft Updater ${PRODUCT_VERSION}]" ;Change title
Caption "$title" ;Caption "$updrSettingsName Updater $updrSettingsStrVer" ;${PRODUCT_VERSION}" ;Change title
!if ${PRODUCT_EDITION} != "Corp"
 BrandingText "Puchisoft Dispatcher"
!else
 BrandingText "$updrSettingsBrandingText"
!endif
SubCaption 3 " " ;Gets rid of stupid "Installing..." addon title
SubCaption 4 " " ;Gets rid of stupid "Installing..." addon title
;Icon "${NSISDIR}\Contrib\Graphics\Icons\box-install.ico"
icon cog2.ico
RequestExecutionLevel user

#MiscButtonText "Back" "OK" "Cancel" "OK" ;Hack 'Next'/'Close' button to say OK, so it's not inappropriate when the ad is not shown (in free, with noUpdates, for example)
MiscButtonText "$btnTextBack" "$btnTextOK" "$btnTextCancel" "$btnTextOK" ;Hack 'Next'/'Close' button to say OK, so it's not inappropriate when the ad is not shown (in free, with noUpdates, for example)

XPStyle on
SetFont "Verdana" 8
InstallColors 000000 FFFFFF

ShowInstDetails show

;;Declare things
var updrSettingsFile
var updrSettingsUVer
var updrSettingsUType
var updrSettingsName
var updrSettingsNameSafe
var updrSettingsGID
var updrSettingsBrandingText
var updrSettingsIntVer
var updrSettingsStrVer
var updrSettingsExePath
var updrSettingsExeParams
var updrSettingsKillEXE
var updrSettingsKillEXEOnlyIfNeeded
var updrSettingsOnSuccessUpdate
var updrSettingsOnSuccessNoUpdate
var updrSettingsOnFail
var updrSettingsStatsURL
var appdataSettingsCustomParam
var appdataSettingsMirrorListURL
var mirrorlistFile ; usually same as updrSettingsFile, except when MirrorListURL used

!if ${PRODUCT_EDITION} == "Free"
;;;for ad
Var ad_Dialog
Var ad_Label
var ad_Button
;;
!endif

var title ;used as caption of updater
#MiscButtonText "$btnTextBack" "$btnTextOK" "$btnTextCancel" "$btnTextOK" ;Hack 'Next'/'Close' button to say OK, so it's not inappropriate when the ad is not shown (in free, with noUpdates, for example)
var btnTextOK
var btnTextBack
var btnTextCancel
var resultLangText

var isAdmin ;true:"yes"/other=no

var url_prettyForUserOnly

var maskExtension ;stored in ini too, but named this way to be the same as in compiler.nsi

var int_version_final
var int_version_newer
var str_version_newer

var patch_mapdownloaded
var patch_snapshotdownloaded
var patch_originalfile
var patch_delFilesBacklog
var patch_delFoldersBacklog

var curSubDir

var updrSettingsOnlyCheckEveryXDays
var updrSettingsBaseURL
var curMirrorURLid
var updrSettingsAuthUserPass
;for newly downloaded updaterSettings
var newStrVer
var newUType
var newUpdaterVer ;8
var newPChecksum
var newFirstMirrorURL
var expectedPChecksum
;for downloading
var curFileGetURL
var curFileTargetURL
;for comparing
var md5listFile
var md5listFileLn
var md5listCurFile
var md5listCurMD5
;stamp comparing
var stamp
var newStamp 
;var oldFile
var newStampDay
var stampDay
var stampHour
var newStampHour
var stampMin
var newStampMin
var stampSec
var newStampSec
;var fileDay
;
var allparams
var param1
var param2TillEnd
var bFullRecover
var successStatus ;if this is "Fail", skip to lingerAtEnd
var bEXEWasTerminated

var chkForAdmLvl

Function checkForAdmin
    ;Returns isAdmin with "yes" if: User Has Write Access OR User is running Win9X OR User has Admin rights OR User is has Power User rights
    ; note that a "no" answer generally results in the Updater rebooting to try to get Admin rights; Hence, it's better to err on the side of saying "yes" to avoid infinite loop 
  push $0
  
  strcpy $isAdmin "no"
  
  ClearErrors ;Check for Write Access  
  FileOpen $0 "$EXEDIR\UpdaterTmp.tmp" w
  iferrors checkForAdmin_doneWriteAccessCheck checkForAdmin_WriteAccess
 checkForAdmin_WriteAccess:
    strcpy $isAdmin "yes"
    goto checkForAdmin_doneWriteAccessCheck
 checkForAdmin_doneWriteAccessCheck:
  FileClose $0
  delete "$EXEDIR\UpdaterTmp.tmp"
  
  ClearErrors
	UserInfo::GetName
	IfErrors 0 +3 ;Win9x = always admin
	 strcpy $isAdmin "yes"
	 goto done
	UserInfo::GetAccountType
	Pop $chkForAdmLvl
	;MessageBox MB_OK "AcctType=[$0]"
	strcmp $chkForAdmLvl "Admin" 0 +3
	 strcpy $isAdmin "yes"
	 goto done
  strcmp $chkForAdmLvl "Power" 0 +3 ;power users can also write files into Program Files
	 strcpy $isAdmin "yes"
	 goto done 	 
 done:   
 pop $0
FunctionEnd

Function checkForAdmin_RebootIfNotAdmin
  call checkForAdmin
  strcmp $isAdmin "yes" done         
   SetOutPath "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\"
   File "/oname=${UPDATER_HELPER_CUTENAME}" "UpdaterHelper.exe"
   execshell open "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\${UPDATER_HELPER_CUTENAME}" "runUpdater¤$EXEDIR¤-update¤"
   quit
  done:
FunctionEnd

Function prepareFullRecover
   strcpy $bFullRecover 1
FunctionEnd

Function rebootIntoRecoveryMode
   ifsilent +3
    exec '"$EXEDIR\$EXEFILE" -fullrecover'
    quit ;this is not a failure until all of Updater failed
   clearerrors
   ;!ADMINRIGHTS - This function is called on FileNotFound (when not silent), which can happen before AdminRights are checked - not a problem since it's not silent at this point
   FileOpen $9 "$EXEDIR\Updater.recover" w ;forces a full recovery to happen until success
   FileWrite $9 "Puchisoft"
   FileClose $9
   iferrors +2 ;don't let it start the Updater again, silent fail
   exec '"$EXEDIR\$EXEFILE" /S'
   quit
FunctionEnd

Function IsNewStampNewer ;push new, than old stamp
 pop $stamp
 pop $newStamp ;1st param
 ;MessageBox MB_OK "New[$newStamp] Old[$stamp] "
 ;compare date
 ${WordFind} $stamp "." "+1" $stampDay
 ${WordFind} $newStamp "." "+1" $newStampDay
 intcmp $stampDay $newStampDay 0 positive negative ;less = not possibly newer. equal=maybe. greater=yes
 ;MessageBox MB_OK "Same day"
 ${WordFind} $stamp "." "+2" $stampHour
 ${WordFind} $newStamp "." "+2" $newStampHour 
 intcmp $stampHour $newStampHour 0 positive negative
 ;MessageBox MB_OK "Same hour"
 ${WordFind} $stamp "." "+3" $stampMin
 ${WordFind} $newStamp "." "+3" $newStampMin
 intcmp $stampMin $newStampMin 0 positive negative
 ;MessageBox MB_OK "Same Min"
 ${WordFind} $stamp "." "+4" $stampSec
 ${WordFind} $newStamp "." "+4" $newStampSec
 intcmp $stampSec $newStampSec negative positive negative
 positive:
  ;MessageBox MB_OK "Pos"
  push "true"
  goto fend
 negative:
  ;MessageBox MB_OK "Neg"
  push "false"
 fend:
FunctionEnd

!macro BASEURL_INJECT_AUTH ;Put the User:Pass into the baseURL, if there is one - Having it there when it's not needed is OK - If it's wrong/missing when needed, the user is prompted by inetc
;strcmp $updrSettingsAuthUserPass "" +4  ;//!Hardcoded JUMP //THIS MAKES DISPATCHER CRASH IF IT JUMPS ~invalid opcode something
  ${WordFind} $updrSettingsBaseURL "/" "+3{" $url_prettyForUserOnly ;Remember Just the protocol+domain name, not full URL, for showing the user
  
  ${WordFind} $updrSettingsBaseURL "/" "+2{" $R0
  ${WordFind} $updrSettingsBaseURL "/" "+2}" $R1
 strcmp $updrSettingsBaseURL "" +2 ;if BaseURL was blank, it needs to stay that way to check if the last mirror was reached
  strcpy $updrSettingsBaseURL "$R0/$updrSettingsAuthUserPass$R1" ;always reassemble, no harm done
;messagebox mb_ok "<-> $R0 <-> $R1 <->> $updrSettingsBaseURL <<->" 
!macroend

!macro BIMAGE IMAGE PARMS
	Push $0
	GetTempFileName $0
	File /oname=$0 "${IMAGE}"
	SetBrandingImage ${PARMS} $0
	Delete $0 
	Pop $0
!macroend
AddBrandingImage left 164

Function .onGUIInit 

iffileexists "$EXEDIR\Updater.bmp" 0 +3
   SetBrandingImage /RESIZETOFIT "$EXEDIR\Updater.bmp"
   goto setTheImg
 !insertmacro BIMAGE "Logo${PRODUCT_EDITION}.bmp" /RESIZETOFIT
 setTheImg:
FunctionEnd


Function .onInit
SetdetailsPrint none ;don't print any details
InitPluginsDir
;Include English.ini-Language in exe as fallback
SetOutPath "$PLUGINSDIR"
SetOverwrite on
File "..\Languages\English.ini"
   

strcpy $bFullRecover 0
strcpy $patch_mapdownloaded 0
strcpy $patch_snapshotdownloaded 0
strcpy $successStatus ""

Call GetParameters
Pop $allparams
${WordFind} $allparams " " "+1" $param1 ;first param
${WordFind} $allparams " " "+2*}" $param2TillEnd ;2nd param plus everything after it (so URL with spaces work for -inflate)

strcmp $param1 "-inflate" 0 +2
  call inflateFromBaseURL

;!if ${PRODUCT_EDITION} == "Free"  
; ifsilent 0 +3
;  MessageBox MB_OK "Silent updates are not allowed in the Freeware Edition!"
;  quit
;!endif
  

;Run in Quiet Mode? No gui unless update found
strcmp $allparams "-quiet" 0 +2
 setsilent silent
strcmp $allparams "-silentcheckonly" 0 +2
 setsilent silent

;Do Full Recovery?
clearerrors
FileOpen $0 "$EXEDIR\Updater.recover" r ;if exists, do recovery
FileClose $0
iferrors +2
  call prepareFullRecover

strcmp $allparams "-fullrecover" 0 +2 ;Full Recover mode, basically uses sync mode as an exception
  call prepareFullRecover


;;Read Updater.dat
ClearErrors
strcpy $updrSettingsFile "$EXEDIR\Updater.dat"
readinistr $updrSettingsUVer $updrSettingsFile "Updater" "Stamp" ;make sure file exists
IfErrors 0 +2
  call noupdatersettings
 
readinistr $updrSettingsUType $updrSettingsFile "Updater" "Mode" ;(1=Patch,3=Sync,4=SyncComp)
!if ${PRODUCT_EDITION} == "Corp"
readinistr $updrSettingsBrandingText $updrSettingsFile "Updater" "BrandingText"
 ;strcmp $updrSettingsBrandingText "" 0 +2 ;instead allow zero branding text
  ;strcpy $updrSettingsBrandingText "Puchisoft Dispatcher"
!endif
readinistr $updrSettingsName $updrSettingsFile "Updater" "PName"

;must strip illegal filename chars out of ProjName for things like storing data with that file/foldername
strcpy $updrSettingsNameSafe $updrSettingsName 
;illegal:  : / \ * | < > ? "
${CharStrip} ":" "$updrSettingsNameSafe" $updrSettingsNameSafe
${CharStrip} "/" "$updrSettingsNameSafe" $updrSettingsNameSafe
${CharStrip} "\" "$updrSettingsNameSafe" $updrSettingsNameSafe
${CharStrip} "*" "$updrSettingsNameSafe" $updrSettingsNameSafe
${CharStrip} "|" "$updrSettingsNameSafe" $updrSettingsNameSafe
${CharStrip} "<" "$updrSettingsNameSafe" $updrSettingsNameSafe
${CharStrip} ">" "$updrSettingsNameSafe" $updrSettingsNameSafe
${CharStrip} "?" "$updrSettingsNameSafe" $updrSettingsNameSafe
${CharStrip} '"' "$updrSettingsNameSafe" $updrSettingsNameSafe
; $R0 == "9921"
                                                                       
readinistr $updrSettingsStatsURL $updrSettingsFile "Updater" "StatsURL"
readinistr $updrSettingsGID $updrSettingsFile "Updater" "GID"
readinistr $updrSettingsIntVer $updrSettingsFile "Updater" "MyVer" 
readinistr $updrSettingsStrVer $updrSettingsFile "Updater" "MyVer$$" 
readinistr $updrSettingsExePath $updrSettingsFile "Updater" "EXEPath" 
readinistr $updrSettingsExeParams $updrSettingsFile "Updater" "EXEParams" 
;(1-Never,2-OnlyWhenNoUpd,3-OnlyWhenUpd,4-Always)
readinistr $1 $updrSettingsFile "Updater" "Auto"
strcpy $updrSettingsOnSuccessUpdate $1 1 0
strcpy $updrSettingsOnSuccessNoUpdate $1 1 1
strcpy $updrSettingsOnFail $1 1 2
;MessageBox MB_OK "$updrSettingsOnSuccessUpdate $updrSettingsOnSuccessNoUpdate $updrSettingsOnFail]"

readinistr $maskExtension $updrSettingsFile "Updater" "MaskExtension"
 strcmp $maskExtension "" 0 +2 ;if blank, set to default of ".zip" -- this is needed for old projects that got dragged into being part of the .zip mask-extension trend
  strcpy $maskExtension ".zip"

readinistr $updrSettingsKillEXE $updrSettingsFile "Updater" "KillEXE"
readinistr $updrSettingsKillEXEOnlyIfNeeded $updrSettingsFile "Updater" "KillEXEOnlyIfNeeded"
readinistr $updrSettingsOnlyCheckEveryXDays $updrSettingsFile "Updater" "XDays" 

createdirectory "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates" ;XP Needs folders to be explicitly created exist

;Just set Auth info and quit? -- Can't do this earlier, because of the variables needed to read this file
${WordFind} $allparams " " "+1" $0
strcmp $0 "-setauth" 0 SetAuthDone
  strcmp $0 $allparams 0 +3 ;if there are no further params for user/pass, clear info
    deleteinisec "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "Auth"
    quit 
  ${WordFind} $allparams " " "+2" $1
  ${WordFind} $allparams " " "+3" $2
  clearerrors
  writeinistr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "Auth" "User" $1
  writeinistr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "Auth" "Pass" $2
  iferrors 0 +2
    messagebox MB_OK|MB_ICONEXCLAMATION 'Could not set authentication'
  quit
SetAuthDone:

;Set Custom URL Param and quit? -- Can't do this earlier, because of the variables needed to read this file
${WordFind} $allparams " " "+1" $0
strcmp $0 "-setcustomurlparam" 0 SetCustomURLParamDone
  strcmp $0 $allparams 0 +3 ;if there are no further params for user/pass, clear info
    deleteinistr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "StatsURL" "CustomParam"
    quit
  ${WordFind} $allparams " " "+2*}" $1
  clearerrors
  writeinistr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "StatsURL" "CustomParam" $1  
  iferrors 0 +2
    messagebox MB_OK|MB_ICONEXCLAMATION 'Could not set Custom URL Parameter'
  quit
SetCustomURLParamDone:
;Custom URL Param is read in right before usage

;Set MirrorList URL Param and quit? -- Can't do this earlier, because of the variables needed to read this file
${WordFind} $allparams " " "+1" $0
strcmp $0 "-setmirrorlisturl" 0 SetMirrorListDone
  strcmp $0 $allparams 0 +3 ;if there are no further params for user/pass, clear info
    deleteinistr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "MirrorList" "URL"
    quit 
  ${WordFind} $allparams " " "+2*}" $1
  clearerrors
  writeinistr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "MirrorList" "URL" $1  
  iferrors 0 +2
    messagebox MB_OK|MB_ICONEXCLAMATION 'Could not set MirrorList URL'
  quit
SetMirrorListDone:
readinistr $appdataSettingsMirrorListURL "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "MirrorList" "URL" ;These are read from the APPData settings file to preserve this data

;Read in Auth_User and Auth_Pass for Web Authentication, optionally injected in settings file by Author Program only
readinistr $1 "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "Auth" "User" ;These are read from the APPData settings file to preserve this data
readinistr $2 "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "Auth" "Pass" ;...to make it easy for authors to set this info, the parameter setauth exists
strcpy $updrSettingsAuthUserPass ""
strcmp $1 "" +2 ;leave result blank if username is blank
  strcpy $updrSettingsAuthUserPass "$1:$2@"

;;Check if we are trying to update the Updater right now
strcmp $EXEFile "UpdaterNew.exe" 0 noUpdaterUpdate
;KillProcDLL::KillProc "Updater.exe"
;fct::fct /WTP "$updrSettingsName Updater" ;close old updater - does this suicide?
clearerrors
replaceUpdaterExe:
sleep 1000
delete "$EXEDIR\Updater.exe"
sleep 1000
copyfiles /SILENT /FILESONLY "$EXEDIR\UpdaterNew.exe" "$EXEDIR\Updater.exe"
iferrors 0 +3
  messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION 'Could not update the Updater. Please Retry.$\r$\n$\r$\nWarning: If you Cancel, you must manually rename UpdaterNew.exe to Updater.exe in $EXEDIR' /SD IDOK IDRETRY replaceUpdaterExe 
  quit
;updater update success
ReadINIStr $0 "$EXEDIR\Updater.dat" "Tmp" "UpdaterStampTmp" ;move from tmp into actual used one
WriteINIStr "$EXEDIR\Updater.dat" "Updater" "Stamp" $0
ifsilent +3 ;keep it silent, if it is
exec '"$EXEDIR\Updater.exe" -update' ;update is there so an update is done, even though a check was just done
quit
exec "$EXEDIR\Updater.exe /S"
quit

noUpdaterUpdate:
delete "$EXEDIR\UpdaterNew.exe"
strcmp $EXEFile "Updater.exe" +2
  MessageBox MB_OK|MB_ICONEXCLAMATION "This Updater should be named Updater.exe (not $EXEFile). Renaming this Updater prevents it from updating itself properly."
  
;Set program's title
!insertmacro GETLANGTEXT "TITLE" "" ""
strcpy $title $resultLangText  

;Set buttons
!insertmacro GETLANGTEXT "BUTTON_OK" "" ""
strcpy $btnTextOK $resultLangText
!insertmacro GETLANGTEXT "BUTTON_Back" "" ""
strcpy $btnTextBack $resultLangText
!insertmacro GETLANGTEXT "BUTTON_Cancel" "" ""
strcpy $btnTextCancel $resultLangText

FunctionEnd

Function noupdatersettings
   ;OpenSourceEdition
   MessageBox MB_OK|MB_ICONSTOP "Updater.dat is missing or corrupted! Please re-install.$\n[Puchisoft Dispatcher ${PRODUCT_EDITION}(OpenSourceEdition) ${PRODUCT_VERSION}]"      
   Quit
FunctionEnd



Section ; GUI Starts here
 
 ;Remove the main Progress Bar
 FindWindow $0 "#32770" "" $HWNDPARENT
 FindWindow $1 "msctls_progress32" "" $0
 ShowWindow $1 ${SW_HIDE}

!insertmacro WRITESTATUS "Loading..."

!if ${PRODUCT_EDITION} == "Free"
 !insertmacro WRITELN "Puchisoft Dispatcher: Freeware Edition ${PRODUCT_VERSION}"   
  #intcmp $updrSettingsUType 2 0 0 freeCheckSyncMode ;if patch mode, stay
  #!insertmacro WRITELN " Demo of Patch Mode. Do Not Distribute!" 
 freeCheckSyncMode: 
 !insertmacro WRITELN " For Non-Commercial Use Only."
 ifsilent +2
  sleep 1000
!endif
!if ${PRODUCT_EDITION} == "Pro"
 !insertmacro WRITELN "Puchisoft Dispatcher: Professional Edition ${PRODUCT_VERSION}"
!endif

strcmp $successStatus "Fail" lingerAtEnd ;may already have failed in init

intcmp $updrSettingsUType 1 +2 0 +2 ;if < 1 ; check if settings exist
 call noupdatersettings
 
strcmp $allparams "-needadmin" 0 +3
  messagebox mb_ok|MB_ICONSTOP "Sorry, you can't proceed without Administrator rights. Please get an Administrator to assist you."
  call onFailQuit 

createdirectory "$APPDATA\PuchisoftDispatcher\"

;Normal operations below, check if it's been X days
strcmp $allparams "-check" beginUpdateCheck ;ignore how long it's been, if param is there
strcmp $allparams "-update" beginUpdateCheck ;ignore how long it's been, if param is there
strcmp $bFullRecover 1 beginUpdateCheck ;full recover ignores this too
call TodaySerial
pop $0
ReadINIStr $1 "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "Check" "LastCheckedDay"
IntOp $0 $0 - $1
;MessageBox MB_OK "$0 days, $1"
intCmp $0 $updrSettingsOnlyCheckEveryXDays beginUpdateCheck 0 beginUpdateCheck
!insertmacro WRITELN "Not checking for updates."
!insertmacro WRITELN " It has not been $updrSettingsOnlyCheckEveryXDays day(s) yet (only $0)."
!insertmacro WRITELN " Force update check with -check parameter."
strcpy $successStatus "SuccessNoUpdate"
goto successNoUpdates

beginUpdateCheck:

;Figure out proper MirrorList File
strcpy $mirrorlistFile $updrSettingsFile ;mirrorlistFile defaults to Updater.dat
strcmp $appdataSettingsMirrorListURL "" initFirstMirrorURL ;If no MirrorList URL set, just go read Mirrors from Updater.dat as normal

;Download MirrorList URL
!insertmacro GETLANGTEXT "STATUS_ConnectingTo" "Mirror List Server" ""
!insertmacro WRITESTATUS "$resultLangText"
!insertmacro WRITELN "$resultLangText" ;set by inject macro
strcpy $curFileGetURL $appdataSettingsMirrorListURL
strcpy $curFileTargetURL "$PLUGINSDIR\mirrorlist.ini"
   inetc::get /SILENT $curFileGetURL $curFileTargetURL /END
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" mirrorListURLDownloaded
     !insertmacro WRITELN "Mirror List Server unreachable! [$R0]" 
     ;StrCmp $R0 "File Open Error" +2 ;don't check for any more mirrors, client is at fault ;
     ;StrCmp $R0 "Terminated" 0 +3
       
       Call downloadFailed
       goto lingerAtEnd
     ;mirror is down, move on     
   
mirrorListURLDownloaded:  
strcpy $mirrorlistFile "$PLUGINSDIR\mirrorlist.ini" ;use downloaded list instead

initFirstMirrorURL:
;Read first Mirror URL
strcpy $curMirrorURLid 0 ;incremented later
readinistr $updrSettingsBaseURL $mirrorlistFile "Mirrors" "$curMirrorURLid" 
!insertmacro BASEURL_INJECT_AUTH

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;DL CUR.VER;;;;;;;;;;;;;;;;
;;all Modes do this, even recovery (to ensure that curVer is not less than mine)
dlVer:

!insertmacro GETLANGTEXT "STATUS_ConnectingTo" "$url_prettyForUserOnly" ""
!insertmacro WRITESTATUS "$resultLangText"
!insertmacro WRITELN "$resultLangText" ;set by inject macro

;;Download new cur.ver
strcpy $curFileGetURL '$updrSettingsBaseURL\ver$maskExtension'

Push $curFileGetURL ;this is used to replace \ with /
Push "\"
Push "/"
Call StrRep
Pop "$curFileGetURL" ;result

;MessageBox MB_OK $curFileGetURL
strcpy $curFileTargetURL "$PLUGINSDIR\cur.ver"
   inetc::get /SILENT $curFileGetURL $curFileTargetURL /END
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" foundGoodMirror
     StrCmp $R0 "File Open Error" +2 ;don't check for any more mirrors, client is at fault ;
     StrCmp $R0 "Terminated" 0 +3
       Call downloadFailed
       goto lingerAtEnd
     ;mirror is down, move on
     !insertmacro WRITELN "Mirror down! [$R0]"
     clearerrors  
     ;this is the same code as is used when outdated mirror found
     intop $curMirrorURLid $curMirrorURLid + 1 ;incremented later
     readinistr $updrSettingsBaseURL $mirrorlistFile "Mirrors" "$curMirrorURLid"
     !insertmacro BASEURL_INJECT_AUTH
     strcmp $updrSettingsBaseURL "" 0 dlVer
       !insertmacro WRITELN "The update server(s) are currently unreachable."
       !insertmacro WRITELN " Check your internet connection, and try again later."
       call onFail
       goto lingerAtEnd 	   
	   goto dlVer ;try again w/ new mirror

foundGoodMirror:
;!insertmacro WRITELN "Connected." ;No need to mention this. We are miliseconds away from saying if new version out there or not    

ClearErrors
;open .ver file (md5 of md5list file)
FileOpen $md5listFile "$PLUGINSDIR\cur.ver" r
IfErrors readwriteErr
FileRead $md5listFile $int_version_final
FileClose $md5listFile

strcpy $int_version_newer $int_version_final

;see if new ver is newer than us
strcmp $bFullRecover 1 0 dlVer_notRecover ;in Full Recovery, only the downloaded Ver being LOWER than mine, is reason not to recover
 intcmp $updrSettingsIntVer $int_version_final 0 0 mirrorOutdated
 !insertmacro WRITELN "Starting Full Recover..."
 goto dlVer_proceed
dlVer_notRecover:
intcmp $updrSettingsIntVer $int_version_final successNoUpdates 0 mirrorOutdated ;check if newer version
!insertmacro GETLANGTEXT "STATUS_NewVersion" "" ""
!insertmacro WRITELN "$resultLangText"

dlVer_proceed: ;New version detected



;There is a new version, check that No Updater Update, or change of Update Mode, and deal with them if needed
strcpy $successStatus "" ;There was no change in WWW location (default)
call checkNewUpdaterDat
strcmp $successStatus "Fail" lingerAtEnd
strcmp $successStatus "Loop" dlVer


;Prompt user if he wants to update
strcpy $4 ""
call promptToUpdate ;knows to auto-accept in full recover
strcmp $R5 "OK" +2 ;if update was choosen
 call onFailQuit
call checkForAdmin_RebootIfNotAdmin
 
strcpy $str_version_newer $newStrVer ;newer is used by patch chaining to say where we are

strcmp $bFullRecover 1 syncMode2

;which mode does this updater use?
strcmp $updrSettingsUType 1 patchMode2
strcmp $updrSettingsUType 2 patchMode2
strcmp $updrSettingsUType 3 syncMode2
strcmp $updrSettingsUType 4 syncMode2
call noupdatersettings

mirrorOutdated:
!insertmacro WRITELN "Update mirror is outdated!"
  ;this is the same code as is used when dling cur.ver
  intop $curMirrorURLid $curMirrorURLid + 1 ;incremented later
  readinistr $updrSettingsBaseURL $mirrorlistFile "Mirrors" "$curMirrorURLid"
  !insertmacro BASEURL_INJECT_AUTH
  strcmp $updrSettingsBaseURL "" 0 dlVer
    !insertmacro WRITELN "The update mirror(s) are currently unreachable." 
    !insertmacro WRITELN " Check your internet connection, and try again later."
    call onFail
    goto lingerAtEnd 	   
	goto dlVer ;try again w/ new mirror

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;SYNC MODE;;;;;;;;;;;;;;;;
syncMode2:

!insertmacro GETLANGTEXT "STATUS_DownloadingAsNeeded" "" ""
!insertmacro WRITELN "$resultLangText"
!insertmacro WRITESTATUS "$resultLangText"

syncModeDownloadSnapshot:
;dl new Updater.snapshot
;MessageBox MB_OK "$md5listFileLn+$0 Bad Snapshot, updating..."
   ;execshell open "$PLUGINSDIR"
   ;messagebox mb_ok "before [$curFileGetURL] [$curFileTargetURL] [$R0]"
   strcpy $curFileGetURL '$updrSettingsBaseURL\snapshot$maskExtension'
   Push $curFileGetURL ;this is used to replace \ with /
   Push "\"
   Push "/"
   Call StrRep
   Pop "$curFileGetURL" ;result
   strcpy $curFileTargetURL "$PLUGINSDIR\Updatersnapshot.7z"
   inetc::get /CAPTION "$updrSettingsName Updater" /RESUME "Download failed. Try to resume?" /TRANSLATE "Downloading Snapshot..." "Connecting ..." second minute hour s "%dkB (%d%%) of %dkB @ %d.%01dkB/s" "(%d %s%s remaining)" $curFileGetURL $curFileTargetURL /END  
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" syncModeGotSnapshot 
     ;messagebox mb_ok "What? [$curFileGetURL] [$curFileTargetURL] [$R0]"
     Call downloadFailedAllowRetry
     StrCmp $R1 "Retry" syncModeDownloadSnapshot     
     goto lingerAtEnd

syncModeGotSnapshot:

;extract Snapshot
SetOutPath "$PLUGINSDIR\" ;extract to cur folder in appdata
  Push "$PLUGINSDIR\Updatersnapshot.7z" ;7zip source ; was .lzma
  Push "$PLUGINSDIR\deleteme.tmp" ;tmpfile
  ExtractDllEx::extract
  Pop $R0
  StrCmp $R0 success +3
   messagebox mb_ok "Update data (snapshot$maskExtension) is corrupt. Please try again later."
   call OnFailQuit 
  rename "$PLUGINSDIR\orig.tmp" "$PLUGINSDIR\Updater.snapshot"

strcmp $bFullRecover 1 +2
call reportStats


ClearErrors
;open md5 list
FileOpen $md5listFile "$PLUGINSDIR\Updater.snapshot" r
IfErrors readwriteErr

;we'll be downloading to this
createdirectory "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates"

md5readLn: ;read each line
!insertmacro WRITESTATUS "Scanning for updated files..."
FileRead $md5listFile $md5listFileLn
StrCmp $md5listFileLn "" md5listdone ;if this line is blk, exit the loop
StrCmp $md5listFileLn "X" recoveryDisallowed ;X is special and means Recovery is disallowed
;line is read here, and ensured not to be blank
${WordFind} $md5listFileLn "¤" "+1" $md5listCurFile ;Think String Parser
${WordFind} $md5listFileLn "¤" "+2" $md5listCurMD5

;Files in the root folder have a \ before their name. This is ugly, and gets put into the URL later, causing a double //, making Amazon CloudFront fail (mantis bug #13)
;Note that the file name is the full path of the file, so \ are proper in a later part of the file name!
${WordFind} $md5listCurFile "\" "+1*}" $md5listCurFile

md5dll::GetMD5File "$EXEDIR\$md5listCurFile" ; get the MD5 of the file on the user's PC
Pop $0
StrCmp $md5listCurMD5 $0 md5readLn ;if the MD5s are equal, next file
md5dll::GetMD5File "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$md5listCurFile" ; get the MD5 of the file in temp App Data Downloaded Updates folder
Pop $0
StrCmp $md5listCurMD5 $0 md5readLn ;if the MD5s are equal, next file
;Messagebox MB_OK "File[$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$md5listCurFile] File MD5[$0] Snap's MD5[$md5listCurMD5]"

${WordFind} $md5listFileLn "¤" "+3" $0 ;this will be an "x" if the file was "excluded"
IfFileExists "$EXEDIR\$md5listCurFile" 0 md5readLnGetReadyToDownload ;if it doesn't exist, download no matter what
;if it exists, make sure it's not update excluded
strcmp $0 "x" md5readLn ;if it's excluded, next file

;MD5 mismatch, check that file is writable ;NO MORE NEED, this is just done by CopyFiles over at end
md5readLnCheckCanWriteFile: 
clearerrors
FileOpen $0 "$EXEDIR\$md5listCurFile" a
FileClose $0
iferrors 0 md5readLnGetReadyToDownload
 strcpy $bEXEWasTerminated "0"
 call PromptToClose
 strcmp $bEXEWasTerminated "1" md5readLnCheckCanWriteFile
 !insertmacro GETLANGTEXT "MSG_FileNotWritable" "$md5listCurFile" ""  
 messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$resultLangText" /SD IDCANCEL IDRETRY md5readLnCheckCanWriteFile ;!Lang
 call onFail
 goto lingerAtEnd

md5readLnGetReadyToDownload:
;Create dir to make sure file can actually be downloaded into it
 strcpy $curSubDir ""
 ;gets number of folders this file is locally deep
 ${WordFind} "$md5listCurFile\" "\" "*" $R0 ;number of dirs
 intop $R0 $R0 - 1
 strcmp $R0 0 md5readLnGetReadyToDownloadMidMakeFolder ;If it's the root folder, the following expression gets the wrong thing, so just left it as blank from before
   ${WordFind} "$md5listCurFile\" "\" "+$R0{" $curSubDir ;local dir path -> $curSubDir
 md5readLnGetReadyToDownloadMidMakeFolder:
 ;messagebox mb_OK "file[$md5listCurFile] dir[$curSubDir][$R0]"
 strcmp $R0 "0" md5readLnStartDownload ;$curSubDir can't/doesn't need to be made w/out any dir lvls
  createdirectory "$EXEDIR\$curSubDir\" 
  createdirectory "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$curSubDir\"
  
 md5readLnStartDownload: ;this is referenced by Verify Error below
 
!insertmacro WRITELN " Downloading: $md5listCurFile"
;download the single file
   strcpy $0 ""
   strcmp $updrSettingsUType 1 +3 ;No Compression  means the download destination has no $maskExtension; with comp, we later extract
   strcmp $updrSettingsUType 3 +2
     strcpy $0 "$maskExtension" ;was .lzma
   ;download to appdata initially, we'll copy it over when it's all downloaded
   strcpy $curFileTargetURL "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$md5listCurFile$0"
   strcpy $curFileGetURL '$updrSettingsBaseURL\sync\$md5listCurFile$maskExtension'
   
   Push $curFileGetURL ;this is used to replace \ with /
   Push "\"
   Push "/"
   Call StrRep
   Pop "$curFileGetURL" ;result
   
   ;inetc::get /CAPTION "Downloading new version..." /BANNER "Downloading $curFileGetURL" $curFileGetURL $curFileTargetURL
   inetc::get /CAPTION "$updrSettingsName Updater" /RESUME "Download failed. Try to resume?" /TRANSLATE "Downloading $md5listCurFile..." "Connecting ..." second minute hour s "%dkB (%d%%) of %dkB @ %d.%01dkB/s" "(%d %s%s remaining)" $curFileGetURL $curFileTargetURL /END
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" md5readLnDownloadGotFile
     Call downloadFailedAllowRetry
     strcmp $R1 "Retry" md5readLnStartDownload
     goto lingerAtEnd

 md5readLnDownloadGotFile:
  ;do this part only if we are using Compression
  strcpy $3 "No Compression"
  strcmp $updrSettingsUType 1 md5readLnVerifyNewFile ;Patch, No Comp
  strcmp $updrSettingsUType 3 md5readLnVerifyNewFile ;Sync, No Comp
    
  
  SetOutPath "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$curSubDir\" ;extract to cur folder in appdata (yes, even MD5 lists have sub-dirs!, don't remove $curSubDir again)
  Push "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$md5listCurFile$maskExtension" ;7zip source ; was .lzma
  Push "$PLUGINSDIR\delme.tmp" ;tmpfile
  ExtractDllEx::extract
  pop $2
  strcpy $3 "Extraction Result: $2"
  ;messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$2 $APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$md5listCurFile$maskExtension]["
 
  delete "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$md5listCurFile$maskExtension" ;was .lzma ;needed to not copy compressed stuff into actual live folder later
  ;no verify extraction success, we'll do that right below anyway
  
  
 md5readLnVerifyNewFile: ;Important -- make sure the right version of the file was obtained from Update Mirror
  md5dll::GetMD5File "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$md5listCurFile" ; get the MD5 of the file just downloaded/extracted
  Pop $1
  StrCmp $md5listCurMD5 $1 md5readLn ;if the MD5s are equal, go to next file
   !insertmacro WRITELN "Download corrupt: $md5listCurFile"
   FileClose $md5listFile ;if we restart syncmode, we must let this old snapshot go so a new one can be put there
   strcpy $allparams "-update" ;This is to mean that they won't be prompted to update
   !insertmacro GETLANGTEXT "MSG_CorruptDownload" "$md5listCurFile" ""
   messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$resultLangText$\n$\nDebug info:$\n[$3$\nExpected:$md5listCurMD5!=Received:$1]" /SD IDCANCEL IDRETRY dlver ;!Lang    
    call onFail
    goto lingerAtEnd
    
;//
goto md5readLn

;done reading
md5listdone:
 !insertmacro GETLANGTEXT "STATUS_PuttingIntoPlace" "" ""
 !insertmacro WRITELN "$resultLangText"
 !insertmacro WRITESTATUS "$resultLangText"
 ;Kill Prog EXE; if it actually happens here, it's done more out of protocol than out of write-access scare...but close it!
     ;call PromptToClose ;No longer done. If user checked Only Close as needed, it wasn't needed - if he did not, it shouldn't be closed to upload the deal
   clearerrors
   copyfiles /SILENT "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\*" "$EXEDIR\"
   iferrors 0 md5listdone2
    !insertmacro GETLANGTEXT "MSG_CantPutIntoPlace" "$EXEDIR" ""
    messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$resultLangText" /SD IDCANCEL IDRETRY md5listdone ;!Lang    
    call onFail
    goto lingerAtEnd
    
md5listdone2:    
rmdir /r /REBOOTOK "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\"


FileClose $md5listFile


goto end

recoveryDisallowed:
;delete "$EXEDIR\Updater.recover" ;if it's probably not allowed, don't make the updater try it every time
  !insertmacro GETLANGTEXT "MSG_RecoveryForbidden" "" ""
 !if ${PRODUCT_EDITION} == "Free"
  strcpy $resultLangText "$resultLangText { WARNING: This is in violation of the Freeware license of Puchisoft Dispatcher. Please purchase Dispatcher to use this feature! }"
  ;execshell "open" "http://puchisoft.com"
 !endif 
  MessageBox MB_OK|MB_ICONSTOP  "$resultLangText"
  call onFail
  goto lingerAtEnd

;;;;SYNC END;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;PATCH MODE;;;;;;;;;;;;;;;;
patchMode2:

clearerrors ;this must be done due to assumption of patch mode that if a file to be patched exists in this folder, it must be newer than the one in EXEDIR
rmdir /r "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\"
iferrors 0 +4
MessageBox MB_OK|MB_ICONSTOP "Unable to clear folder: $APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\"
   call onFail
   goto lingerAtEnd
   
createdirectory "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\" ;can't write files there if it doesn't exist
   
fileopen $patch_delFilesBacklog "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\UpdaterDelFilesBacklog.tmp" w
fileopen $patch_delFoldersBacklog "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\UpdaterDelFoldersBacklog.tmp" w
iferrors 0 +4
MessageBox MB_OK|MB_ICONSTOP "Can't write to: $APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\"
   call onFail
   goto lingerAtEnd

patchMode_begin:

#!if ${PRODUCT_EDITION} == "Free"
#intcmp $int_version_final 22 +3 +3 0
# MessageBox MB_OK|MB_ICONSTOP  "The trial of Patch Mode for this project has expired. The Freeware Edition only supports Sync Mode." 
# quit
#!endif

!insertmacro GETLANGTEXT "STATUS_UpdatingFromTo" "$updrSettingsStrVer" "$str_version_newer"
!insertmacro WRITELN "$resultLangText"
!insertmacro WRITESTATUS "$resultLangText"

;Check if we already have the patch we need (maybe if we tried to use it, but had some file in use)
iffileexists "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updater($updrSettingsIntVer-$int_version_newer).patch" gotThePatch

getThePatch:
!insertmacro GETLANGTEXT "STATUS_DownloadingPatch" "" ""
!insertmacro WRITELN "$resultLangText"
;;Download patch
strcpy $curFileGetURL '$updrSettingsBaseURL\patch\patch$updrSettingsIntVer_$int_version_newer$maskExtension' ;.patch

Push $curFileGetURL ;this is used to replace \ with /
Push "\"
Push "/"
Call StrRep
Pop "$curFileGetURL" ;result

;download this patch
strcpy $curFileTargetURL "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updater($updrSettingsIntVer-$int_version_newer).patch"
   ;inetc::get /CAPTION "Downloading patch data..." /BANNER "Downloading Patch" $curFileGetURL $curFileTargetURL ;!!!
   inetc::get /CAPTION "$updrSettingsName Updater" /RESUME "Download failed. Try to resume?" /TRANSLATE "Downloading Patch ($updrSettingsStrVer-$str_version_newer)..." "Connecting ..." second minute hour s "%dkB (%d%%) of %dkB @ %d.%01dkB/s" "(%d %s%s remaining)" $curFileGetURL $curFileTargetURL /END
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" justGotThePatch
   StrCmp $R0 "File Not Found (404)" getThePatch_PatchNotFound ;probably means Patch Chain time
   StrCpy $R2 $R0 3 ;Somestimes 550 gets returned when 404 should have been, so look for Patch Chaining there also
   StrCmp $R2 "550" getThePatch_PatchNotFound ;probably means Patch Chain time
    Call downloadFailedAllowRetry
    strcmp $R1 "Retry" getThePatch
    goto lingerAtEnd
    
 getThePatch_PatchNotFound: ;Get Patch Map
  strcmp $patch_mapdownloaded "1" getThePatch_PatchNotFound_fail ;if we already got it, this 404 means the map failed us
  !insertmacro GETLANGTEXT "STATUS_PreparePatchChain" "" ""
  !insertmacro WRITELN "$resultLangText"
  ;;Download patch map
  strcpy $curFileGetURL '$updrSettingsBaseURL\patch\patchmap$maskExtension'
  Push $curFileGetURL ;this is used to replace \ with /
  Push "\"
  Push "/"
  Call StrRep
  Pop "$curFileGetURL" ;result
  ;download patch map
  strcpy $curFileTargetURL "$PLUGINSDIR\patch.map"
   ;inetc::get /CAPTION "Downloading patch map..." /BANNER "Downloading Patch Map" $curFileGetURL $curFileTargetURL ;!!!
   ;inetc::get /CAPTION "$updrSettingsName Updater" /RESUME "Download failed. Try to resume?" $curFileGetURL $curFileTargetURL
   inetc::get /CAPTION "$updrSettingsName Updater" /RESUME "Download failed. Try to resume?" /TRANSLATE "Downloading Patch Map..." "Connecting ..." second minute hour s "%dkB (%d%%) of %dkB @ %d.%01dkB/s" "(%d %s%s remaining)" $curFileGetURL $curFileTargetURL /END
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" patch_lookAtMap 
    Call downloadFailedAllowRetry
    strcmp $R1 "Retry" getThePatch_PatchNotFound
    goto lingerAtEnd
  
 getThePatch_PatchNotFound_fail:
   MessageBox MB_OKCANCEL "The required patch does not exist on the update server. A Full Recover will be used to update." /SD IDOK IDCANCEL +2   
    call rebootIntoRecoveryMode
    call onFail
    goto lingerAtEnd
    
patch_lookAtMap:
strcpy $patch_mapdownloaded "1"
;updrSettingsIntVer is what AddData\Updates is currently at (or main folder)
;int_version_newer is the patch that we are going to apply next
;int_version_final is the version we want to end up at
readinistr $int_version_newer "$PLUGINSDIR\patch.map" "Map" "$updrSettingsIntVer"
readinistr $str_version_newer "$PLUGINSDIR\patch.map" "Names" "$int_version_newer"
strcmp $int_version_newer "" 0 patchMode_begin ;if we're at a dead-end
 ;make note to go into recover mode, but make sure to delete all schedule files first
 strcpy $patch_snapshotdownloaded "1"
 goto p_allPatchesApplied

justGotThePatch:    
call reportStats    
     
gotThePatch:

!insertmacro GETLANGTEXT "STATUS_ApplyingPatchFromTo" "$updrSettingsStrVer" "$str_version_newer"
!insertmacro WRITELN "$resultLangText"
!insertmacro WRITESTATUS "$resultLangText"

;Extract the "patch"(Archive!) into temp folder
  createdirectory "$PLUGINSDIR\patch\"
  SetOutPath "$PLUGINSDIR\patch\"
  Push "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updater($updrSettingsIntVer-$int_version_newer).patch" ;7zip source
  Push "$PLUGINSDIR\patch\delme.tmp" ;tmpfile
  ExtractDllEx::extract
  ;MessageBox MB_OK "Patch extraced to: $PLUGINSDIR\patch\"
  
  ;get the result
  Pop $0
  StrCmp $0 "success" patch_ExtractedOK
    !insertmacro GETLANGTEXT "MSG_CorruptDownload" "Patch" ""
    messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$resultLangText [$0]" /SD IDCANCEL IDRETRY getThePatch    
    call onFail
    goto lingerAtEnd    
  patch_ExtractedOK:
    
  ;we first apply the patch to this location, then copy it over just before we start deleting stuff  
  createdirectory "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\"
  
  clearerrors
  ;;;;big ass patching routine starts here
  StrCpy $5 0 ;Index of NDir loop
  p_newDir_Loop:
   ReadINIStr $6 "$PLUGINSDIR\patch\mod.i" "NDir" $5 ;$6 is the rel path of dir to be made
   strcmp $6 "" p_newFile_Start
   clearerrors
   !insertmacro WRITELN " New folder: $6"
   createdirectory "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$6"
   iferrors somePatchErr
    IntOp $5 $5 + 1
    goto p_newDir_Loop
  
  p_newFile_Start:
   StrCpy $5 0 ;Index
  p_newFile_Loop:
   ReadINIStr $6 "$PLUGINSDIR\patch\mod.i" "NFiles" $5 ;$6 is the rel path of the file
   strcmp $6 "" p_modFile_Start
   !insertmacro WRITELN " New file: $6"
    ;make folder for new file (likely to not exist in tmp space);
    ${WordFind} "$6\" "\" "*" $R0 ;number of dirs
    intop $R0 $R0 - 1
    ${WordFind} "$6\" "\" "+$R0{" $R1 ;local dir path -> R1
    createdirectory "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$R1\"
   clearerrors 
   delete "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$6"
   rename "$PLUGINSDIR\patch\$5.n" "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$6"
   iferrors somePatchErr
    IntOp $5 $5 + 1
    goto p_newFile_Loop

  p_modFile_Start:
   StrCpy $5 0 ;Index
  p_modFile_Loop:
   ReadINIStr $6 "$PLUGINSDIR\patch\mod.i" "MFiles" $5 ;$6 is the rel path of the file
   strcmp $6 "" p_delFile_Start
   ;if this file exists at AppData/Updates, it must be the newer version of file (from previous in patch chain), so try to patch that one
   iffileexists "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$6" 0 +3
    strcpy $patch_originalfile "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$6"
    goto +2
     strcpy $patch_originalfile "$EXEDIR\$6"
   ;did user delete original?
   iffileexists "$patch_originalfile" 0 p_modFile_Loop_Recover ;try to recover it if it's gone from both locations
   ;make sure the file is writable
   clearerrors
   FileOpen $0 "$patch_originalfile" a
   FileClose $0
   iferrors 0 p_modFile_Loop_makeDir
    strcpy $bEXEWasTerminated "0"
    call PromptToClose
    strcmp $bEXEWasTerminated "1" p_modFile_Loop
    !insertmacro GETLANGTEXT "MSG_FileNotWritable" "$6" ""
    messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$resultLangText" /SD IDCANCEL IDRETRY p_modFile_Loop ;!Lang
     call onFail
     goto lingerAtEnd
   p_modFile_Loop_makeDir:  
   ;make folder for new file (likely to not exist in tmp space);
    ${WordFind} "$6\" "\" "*" $R0 ;number of dirs
    intop $R0 $R0 - 1
    ${WordFind} "$6\" "\" "+$R0{" $R1 ;local dir path -> R1
    createdirectory "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$R1\"
   ;patch-start
   ;                      patch file           fileToChange  placetoputUpdatedFile
   vpatch::vpatchfile "$PLUGINSDIR\patch\$5.m" "$patch_originalfile" "$PLUGINSDIR\$5.tmp"
   Pop $1 ;full err message
   !insertmacro WRITELN " Patched file: $6 [$1]"
   StrCpy $2 $1 2 ;trim just the OK part into $2, if it's there
   StrCmp $1 "OK, new version already installed" p_modFile_Loop_End ;since everything is good: do nothing, move on
   StrCmp $2 "OK" p_modFile_Loop_OK ;this puts the patched file into "place"
    StrCmp $1 "No suitable patches were found" p_modFile_Loop_Recover 0 ;If FileModded, try to recover quietly.
    StrCmp $1 "Unable to open source file" p_modFile_Loop_Recover 0 ;If FileDeleted, try to recover quietly. If other issue, fail
        ifsilent +2
         MessageBox MB_OK "$6 could not be patched! (Reason: $1)"
        goto somePatchErr
    p_modFile_Loop_Recover:
    call recoverFromPatchFail
    strcmp $successStatus "Fail" lingerAtEnd
     clearerrors ;if we got here, we assume it was recovered
     goto p_modFile_Loop_End
    p_modFile_Loop_OK:
    clearerrors ;needed, cause BS errors get throws before here from somewhere
    delete "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$6"
    rename "$PLUGINSDIR\$5.tmp" "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$6" ;put updatedFile into its rightful place
    iferrors somePatchErr
   ;/patch-end
    p_modFile_Loop_End:
    IntOp $5 $5 + 1
    goto p_modFile_Loop


  p_delFile_Start: ;All Folder/Files were made and updated, now only deleting is left      
   ;begin of actually deleting files
   StrCpy $5 0 ;Index
  p_delFile_Loop:
   ReadINIStr $6 "$PLUGINSDIR\patch\mod.i" "DFiles" $5 ;$6 is the rel path of the file
   strcmp $6 "" p_delDir_Start    
   !insertmacro WRITELN " Deleted file: $6"
   delete "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$6" ;insta-apply changes only to tmp Updates folder      
   filewrite $patch_delFilesBacklog "$6$\r$\n" ;for deleting live dif files, we add them to the backlog - for patch chaining compatibility   
   ;p_delFile_Loop_next:
    IntOp $5 $5 + 1
    goto p_delFile_Loop

  p_delDir_Start:
   StrCpy $5 0 ;Index
  p_delDir_Loop:
   ReadINIStr $6 "$PLUGINSDIR\patch\mod.i" "DDir" $5 ;$6 is the rel path of the file
   strcmp $6 "" p_done
   !insertmacro WRITELN " Deleted folder: $6"
   rmdir /r "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\$6" ;insta-apply changes only to tmp Updates folder
   filewrite $patch_delFoldersBacklog "$6$\r$\n" ;for deleting live dif files, we add them to the backlog
    IntOp $5 $5 + 1
    goto p_delDir_Loop


  p_done: ;;; one patch routine is done with
  
  ;Check if there are more patches to be applied
  strcmp $int_version_final $int_version_newer p_allPatchesApplied
   strcpy $updrSettingsIntVer $int_version_newer ;we just applied a patch, so we are now at the newer, in temp space only!
   readinistr $updrSettingsStrVer "$PLUGINSDIR\patch.map" "Names" $updrSettingsIntVer ;get name of our current temp version, that we are at; note that only versions patched From are in this list      
   goto patch_lookAtMap
 
 p_allPatchesApplied:
 ;Kill Prog EXE before potentially updating it, if still open ;do this up here, to make that the files can be deleted right now (reboot is used anyway, if needed)
   ;call PromptToClose ;Don't do it to upload OnlyCloseIfNeeded. While it might be needed to delete files, the reboot will take care of it. If that's too late, the user shouldn't have enabled OnlyCloseUpdaterIfNeeded
      
 ;Apply Delete Files/Folder from backlog (important: do this before putting files into place, to avoid deleting files that were since created again in follow-up patches)
 FileClose $patch_delFilesBacklog
 FileClose $patch_delFoldersBacklog
 fileopen $patch_delFilesBacklog "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\UpdaterDelFilesBacklog.tmp" r
 fileopen $patch_delFoldersBacklog "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\UpdaterDelFoldersBacklog.tmp" r
 p_live_delFile_Loop: ;now we actually delete files that some patch in the chain wanted to kill - don't worry if patches re-created the file-putting into place happens after this
  FileRead $patch_delFilesBacklog $6
  strcmp $6 "" p_live_delFolder_Loop
   ;!insertmacro WRITELN "Deleted x file: $6"
   strcpy $6 $6 -2
   p_live_delFile_Loop_retry:
   clearerrors
   delete "$EXEDIR$6" ;reboot not ok, because we fail if we can't delete this file, and if we fail, the file should stay there to avoid crazy-scenarios like update working, then recreating, then rebooting and deling the new file
   iferrors 0 p_live_delFile_Loop ;Can't delete, try closing the software
    strcpy $bEXEWasTerminated "0"
    call PromptToClose
    strcmp $bEXEWasTerminated "1" p_live_delFile_Loop_retry
    !insertmacro GETLANGTEXT "MSG_FileNotWritable" "$6" ""
    messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$resultLangText" /SD IDCANCEL IDRETRY p_live_delFile_Loop_retry ;!Lang
     call onFail
     goto lingerAtEnd
   ;MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Del file: [$EXEDIR$6]" 
   goto p_live_delFile_Loop   
  
 p_live_delFolder_Loop:
  FileRead $patch_delFoldersBacklog $6
  strcmp $6 "" p_allPatchesApplied_PrePuttingIntoPlace
   ;!insertmacro WRITELN "Deleted x folder: $6"
   strcpy $6 $6 -2
   rmdir /r /REBOOTOK "$EXEDIR$6" ;ignore success and try later if needed, since Vista is insane and refuses to delete some folders at whim
   ;MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Del folder: [$EXEDIR$6]"
   goto p_live_delFolder_Loop
   
 p_allPatchesApplied_PrePuttingIntoPlace:
  strcmp $patch_snapshotdownloaded "1" 0 +3 ;if we made a note that we need a full recover at the end, do this
    call prepareFullRecover
    goto syncmode2 ;no need to restart Updater
  goto p_putFilesIntoPlace 
 
 p_putFilesIntoPlace:
  FileClose $patch_delFilesBacklog
  FileClose $patch_delFoldersBacklog
 ;copy over the new files
   !insertmacro GETLANGTEXT "STATUS_PuttingIntoPlace" "" ""
   !insertmacro WRITELN "$resultLangText"   
   clearerrors
   copyfiles /SILENT "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updates\*" "$EXEDIR\"
   iferrors 0 end
    !insertmacro GETLANGTEXT "MSG_CantPutIntoPlace" "$EXEDIR" ""    
    messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$resultLangText" /SD IDCANCEL IDRETRY p_delFile_Start ;!Lang    
    call onFail
    goto lingerAtEnd 
 

;;;;PATCH END
somePatchErr:
   MessageBox MB_YESNO|MB_ICONSTOP "Failed to patch $6! Please make sure no files of $updrSettingsName are in use, and try running the updater again. If this error persists, try restarting your computer. If this file has been deleted, try doing a Full Recover. As a last resort, a re-install may be required.$\n$\nAttempt a Full Recover now?" /SD IDYES IDNO +2 ;!Lang   
    call rebootIntoRecoveryMode
   ;else
   call onFail
   goto lingerAtEnd
  

readwriteErr:
   MessageBox MB_OK|MB_ICONSTOP "Unable to download updates. Please allow read/write access at: $EXEDIR"
   call onFail
   goto lingerAtEnd
   
   
end: ;;updates -both called after sync and patches. Either way updater.dat is updated. For patch, this is essential (new ver)
  strcpy $successStatus "SuccessUpdate"
  !insertmacro GETLANGTEXT "STATUS_Updated" "" ""
  !insertmacro WRITELN "$resultLangText"
  !insertmacro WRITESTATUS "$resultLangText"
  ;Clean up recover mode
  delete "$EXEDIR\Updater.recover"
  ;No need to keep any patches (nor the DelBacklogs), since we just did a successful update
  delete "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\Updater*.*"
  ;remove tmp updates files (at least patch mode hasn't done previously)
  rmdir /r /REBOOTOK "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\" ;was just Updates subdir, but why not nuke it all?
  
 ;Instead of downloading another one, just copy over the already downloaded Updater.dat from the beginning check
  
  replaceUpdaterDat:
  clearerrors
  copyfiles /SILENT /FILESONLY "$PLUGINSDIR\config$maskExtension" "$EXEDIR\Updater.dat" ;move extracted Updater.dat to replace current
  iferrors 0 +2
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Could not update Updater data at $EXEDIR\Updater.dat!" IDRETRY replaceUpdaterDat     
   
  ;make note that last update happened today
  call TodaySerial
  pop $0
  WriteINIStr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "Check" "LastCheckedDay" $0
  
  ;Remove New Version Available data from DATA INI (automatically gone from Updater.dat since it got replaced)
  DeleteINISec  "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "UpdateAvailable"
  
  ;All updates Success
 !insertmacro GETLANGTEXT "MSG_Updated" "" "" 
 #!if ${PRODUCT_EDITION} == "Free"
 # strcpy $0 "$resultLangText$\n$\nThis Updater was made with the freeware edition of Puchisoft Dispatcher! Not for commercial use."
 #!else
  strcpy $0 "$resultLangText"
 #!endif
  ifsilent +2 ;OK mboxes do show up in silent mode
  MessageBox MB_OK|MB_ICONINFORMATION "$0"
 
  ;clear tmp files
  rmdir /r /rebootok "$PLUGINSDIR\"
   
  !if ${PRODUCT_EDITION} != "Free" ;Free version doesn't allow Auto-Close, to show ad  ;runProg still happens later
   !insertmacro OnSomethingDo $updrSettingsOnSuccessUpdate
  !endif   
  goto lingerAtEnd
   
successNoUpdates:
  strcpy $successStatus "SuccessNoUpdate"
  
  ;Clean up recover mode -recover mode can be called upen, even if it wasn't actually needed
  delete "$EXEDIR\Updater.recover"
  
  ;make note that last update happened today
  call TodaySerial
  pop $0
  WriteINIStr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "Check" "LastCheckedDay" $0
  
    
  !insertmacro GETLANGTEXT "STATUS_AlreadyUpToDate" "" ""
  !insertmacro WRITELN "$resultLangText"
  
  !insertmacro OnSomethingDo $updrSettingsOnSuccessNoUpdate
  goto lingerAtEnd  

lingerAtEnd:
  !insertmacro WRITESTATUS "Done"
  
  ;clear tmp files
  rmdir /r /rebootok "$PLUGINSDIR\"
SectionEnd


Page instfiles 
;;;;;;;Ad page - only in Free
!if ${PRODUCT_EDITION} == "Free"
Page custom ad_nsDialogsPage
Function ad_nsDialogsPage
  strcmp $successStatus "SuccessUpdate" +2 ;Only show this after Successful Updates    
    quit
  
	nsDialogs::Create 1018
	Pop $ad_Dialog
	
	${NSD_CreateLabel} 0 0 100% 50% "This Updater was created with Puchisoft Dispatcher.$\n$\nAre you a software developer? Wish you could easily add Auto-Update functionality to your software that is also easy to maintain, all in under 5 minutes? Check out Dispatcher today!$\n$\nThis advertisement is only in the Freeware Edition of Dispatcher."
	Pop $ad_Label
	
	${NSD_CreateButton} 20% 80% 60% 12u "Visit Dispatcher's Website"
	Pop $ad_BUTTON
	GetFunctionAddress $0 ad_OnClick
	nsDialogs::OnClick $ad_BUTTON $0
	
	nsDialogs::Show
FunctionEnd
Function ad_onCLick
  execshell "open" "http://www.puchisoft.com/dispatcher.php"
FunctionEnd
!endif
;;;; end of Ad Page

Function .onInstSuccess ;when gui is closed, AfterOnSomething macros are used here
  ;MessageBox MB_OK "gui close: $successStatus"
  strcmp $successStatus "SuccessUpdate" onCloseSuccessUpdate
  strcmp $successStatus "SuccessNoUpdate" onCloseSuccessNoUpdate
  strcmp $successStatus "Fail" onCloseFail
  MessageBox MB_OK "Invalid successStatus: $successStatus"
  
  onCloseSuccessUpdate:
    !insertmacro AfterOnSomethingDo $updrSettingsOnSuccessUpdate
    goto OnCloseDone
  
  onCloseSuccessNoUpdate:
    !insertmacro AfterOnSomethingDo $updrSettingsOnSuccessNoUpdate
    goto OnCloseDone
    
  onCloseFail:
    !insertmacro AfterOnSomethingDo $updrSettingsOnFail
    goto OnCloseDone
    
  OnCloseDone:
FunctionEnd

Function OnFail
  ;clear tmp files
  rmdir /r /rebootok "$PLUGINSDIR\"

  !insertmacro OnSomethingDo $updrSettingsOnFail ;might insta-quit
  ;otherwise, try to get to lingerAtEnd
  strcpy $successStatus "Fail"
  !insertmacro WRITELN "Failed."
FunctionEnd
Function OnFailQuit ;user aborted, so run or dont program, then quit either way
  ;clear tmp files
  rmdir /r /rebootok "$PLUGINSDIR\"
  
  !insertmacro OnSomethingDo $updrSettingsOnFail ;might insta-quit
  quit
FunctionEnd

Function reportStats
 ;User stats Reporting
 !if ${PRODUCT_EDITION} == "Free"
 !else
 readinistr $appdataSettingsCustomParam "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "StatsURL" "CustomParam" ;These are read from the APPData settings file to preserve this data, can be set with -setcustomurlparam
 strcmp $updrSettingsStatsURL "" +2
  inetc::post "name=$updrSettingsName&gid=$updrSettingsGID&old=$updrSettingsStrVer&new=$newStrVer&custom=$appdataSettingsCustomParam" /SILENT "$updrSettingsStatsURL" "$PLUGINSDIR\reply0.tmp"
 !endif
 
 ;OpenSourceEdition - No stat reporting to Puchisoft
FunctionEnd


Function recoverFromPatchFail ;$6= \game.bat
;don't try to recover anything. Just note that a full recover must be done at the end, and check to make sure this is allowed
;file is at $patch_originalfile
!insertmacro WRITELN "Scheduling recover for: $6"

 recoverDownloadSnapshot:
 ;dl new Updater.snapshot 
   strcpy $curFileGetURL '$updrSettingsBaseURL\snapshot$maskExtension'
   Push $curFileGetURL ;this is used to replace \ with /
   Push "\"
   Push "/"
   Call StrRep
   Pop "$curFileGetURL" ;result
   strcpy $curFileTargetURL "$PLUGINSDIR\Updatersnapshot.7z"
   ;inetc::get /CAPTION "Downloading list of updates..." /BANNER "Downloading $curFileGetURL" $curFileGetURL $curFileTargetURL
   ;inetc::get /CAPTION "$updrSettingsName Updater" /RESUME "Download failed. Try to resume?" $curFileGetURL $curFileTargetURL
   inetc::get /CAPTION "$updrSettingsName Updater" /RESUME "Download failed. Try to resume?" /TRANSLATE "Downloading Snapshot..." "Connecting ..." second minute hour s "%dkB (%d%%) of %dkB @ %d.%01dkB/s" "(%d %s%s remaining)" $curFileGetURL $curFileTargetURL /END
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" recoverGotSnapshot
     Call downloadFailedAllowRetry
     StrCmp $R1 "Retry" recoverDownloadSnapshot     
     goto recoverFromPatchFail_end

recoverGotSnapshot:
;extract Snapshot
SetOutPath "$PLUGINSDIR\" ;extract to cur folder in appdata
  Push "$PLUGINSDIR\Updatersnapshot.7z" ;7zip source ; was .lzma
  Push "$PLUGINSDIR\deleteme.tmp" ;tmpfile
  ExtractDllEx::extract
  Pop $R0
  StrCmp $R0 success +3
   messagebox mb_ok "Update data (snapshot$maskExtension) is corrupt. Please try again later."
   call OnFailQuit 
  rename "$PLUGINSDIR\orig.tmp" "$PLUGINSDIR\Updater.snapshot"

clearerrors
FileOpen $md5listFile "$PLUGINSDIR\Updater.snapshot" r
FileRead $md5listFile $md5listFileLn
FileClose $md5listFile
IfErrors 0 +4
  MessageBox MB_OK|MB_ICONSTOP "Could not write to: $PLUGINSDIR"
  call onFail
  goto recoverFromPatchFail_end

StrCmp $md5listFileLn "X" recoverDisallowed ;X is special and means Recovery is disallowed
 strcpy $patch_snapshotdownloaded "1" ;make note that recover is required after patches are done
 goto recoverFromPatchFail_end

recoverDisallowed:
MessageBox MB_OK|MB_ICONSTOP "The file [$6] can't be patched because it has been modified or deleted. It also can't be recovered because $updrSettingsName does not permit File Recovery. Please reinstall $updrSettingsName." ;!Lang
     call onFail
;//

recoverFromPatchFail_end:
FunctionEnd

Function inflateFromBaseURL ;called by special parameter only, means there is just the Updater.exe in an otherwise empty folder
  ;called via:  Updater.exe -inflate http://example.com/Up/MySoft/.zip
  
  ${WordFind} $param2TillEnd "/" "-2{*" $updrSettingsBaseURL
  ${WordFind} $param2TillEnd "/" "-1"   $maskExtension
  
  iffileexists "$EXEDIR\Updater.dat" 0 +3
    MessageBox MB_OK|MB_ICONEXCLAMATION "Can't inflate into folder: $EXEDIR!$\n$\nTo inflate into a folder, that folder should have only the Updater.exe, nothing else."
    quit
  
  call checkForAdmin
  strcmp $isAdmin "yes" inflate_hasAdmin         
    MessageBox MB_OK|MB_ICONEXCLAMATION "Can't inflate into $EXEDIR without Admin rights!"
    quit
  inflate_hasAdmin:
  
  ;messagebox mb_ok "inflate url[$updrSettingsBaseURL] maskEx[$maskExtension]"  

  ;Get newest Updater.dat from currently understood newest BaseURL
  strcpy $curFileGetURL '$updrSettingsBaseURL\config$maskExtension'
  Push $curFileGetURL ;this is used to replace \ with /
  Push "\"
  Push "/"
  Call StrRep
  Pop "$curFileGetURL" ;result
  strcpy $curFileTargetURL "$PLUGINSDIR\Updaterdat.7z"
   inetc::get /POPUP "" $curFileGetURL $curFileTargetURL /END ;!!!
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" +3 ;! THIS IS A SPECIAL ERROR MESSAGE JUST FOR INFLATE
     MessageBox MB_OK|MB_ICONEXCLAMATION "Download failed [$curFileGetURL]!$\n(Error: $R0) $\n$\nTip: The format of of the 2nd parameter is MirrorURL/ExtensionMask.$\nExample: -inflate http://example.com/Up/MySoft/.zip"
     goto endOfinflateFromBaseURL_quit
  
  ;Extract UpdaterDat  
  SetOutPath "$PLUGINSDIR\" ;extract to cur folder in appdata
  Push "$PLUGINSDIR\Updaterdat.7z" ;7zip source ; was .lzma
  Push "$PLUGINSDIR\delme.tmp" ;tmpfile
  ExtractDllEx::extract
  Pop $R0
  StrCmp $R0 success +3
   messagebox mb_ok "Update data (config$maskExtension) is corrupt. Please try again later."
   call OnFailQuit
  rename "$PLUGINSDIR\orig.tmp" "$PLUGINSDIR\config$maskExtension"
  
 inflate_replaceUpdaterDat:
  clearerrors
  copyfiles /SILENT /FILESONLY "$PLUGINSDIR\config$maskExtension" "$EXEDIR\Updater.dat" ;move extracted Updater.dat to replace current
  iferrors 0 +2
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Could not update Updater data at $EXEDIR\Updater.dat!" IDRETRY inflate_replaceUpdaterDat IDCANCEL endOfinflateFromBaseURL_quit
  
 ;Success - We must now replace this Updater with the one the project we inflated uses (to avoid conflicts of editions/versions of Updater) 
 writeinistr "$EXEDIR\Updater.dat" "Updater" "Stamp" "0.0.0.0" ;write down that we are using the oldest version of the Updater possible, so it must update the Updater.exe
 writeinistr "$EXEDIR\Updater.dat" "Updater" "MyVer" "0"
   FileOpen $9 "$EXEDIR\Updater.recover" w ;forces a full recovery to happen until success (otherwise, update of Updater.exe could make us forget)
   FileWrite $9 "Puchisoft"
   FileClose $9
 call prepareFullRecover ;trigger full recover right now, after we leave this function
 goto endOfinflateFromBaseURL 

 endOfinflateFromBaseURL_quit:
  quit
 endOfinflateFromBaseURL:
FunctionEnd

Function checkNewUpdaterDat
  ;Get newest Updater.dat from currently understood newest BaseURL
  strcpy $curFileGetURL '$updrSettingsBaseURL\config$maskExtension'
  Push $curFileGetURL ;this is used to replace \ with /
  Push "\"
  Push "/"
  Call StrRep
  Pop "$curFileGetURL" ;result
  strcpy $curFileTargetURL "$PLUGINSDIR\Updaterdat.7z"
   inetc::get /SILENT $curFileGetURL $curFileTargetURL /END ;!!!
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" +3
     Call downloadFailed
     goto endOfcheckNewUpdaterDat
  
  ;Extract UpdaterDat  
  SetOutPath "$PLUGINSDIR\" ;extract to cur folder in appdata
  Push "$PLUGINSDIR\Updaterdat.7z" ;7zip source ; was .lzma
  Push "$PLUGINSDIR\delme.tmp" ;tmpfile
  ExtractDllEx::extract
  Pop $R0
  StrCmp $R0 success +3
   messagebox mb_ok "Update data (config$maskExtension) is corrupt. Please try again later."
   call OnFailQuit
  rename "$PLUGINSDIR\orig.tmp" "$PLUGINSDIR\config$maskExtension"
  
     
  ;Read in new Updater.dat info
  strcpy $9 "$PLUGINSDIR\config$maskExtension" ;extracted new Updater.dat
  
  readinistr $newUpdaterVer $9 "Updater" "Stamp"  
  readinistr $newUType $9 "Updater" "Mode"
  readinistr $newStrVer $9 "Updater" "MyVer$$"
  
  !if ${PRODUCT_EDITION} != "Free" 
   readinistr $newPChecksum $9 "Updater" "P"
  !endif
  readinistr $newFirstMirrorURL $9 "Mirrors" "0"
  
  ;update current behavior from new ini ; only those settings that make sense
  readinistr $updrSettingsExePath $9 "Updater" "EXEPath" ;if exepath changed, this way we launch the new exepath after the update
  readinistr $updrSettingsExeParams $9 "Updater" "EXEParams" ;same ;Note: we still kill the old exe, because we hope he got it right the first time

  readinistr $8 $9 "Updater" "Auto" ;might as well load-in whatever is now the desired behavior
   strcpy $updrSettingsOnSuccessUpdate $8 1 0
   strcpy $updrSettingsOnSuccessNoUpdate $8 1 1
   strcpy $updrSettingsOnFail $8 1 2

  ;write fact that update is available to ini file, only for User Programs to look at; this can't be done without getting new .dat, since we write the new verStr
  WriteINIStr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "UpdateAvailable" "UpdateAvailable" "1"       ;write these 2 always
  WriteINIStr "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID.data" "UpdateAvailable" "NewVersionName" $newStrVer
  WriteINIStr "$EXEDIR\Updater.dat" "UpdateAvailable" "UpdateAvailable" "1"                                                            ;these Only if run as Admin, by chance
  WriteINIStr "$EXEDIR\Updater.dat" "UpdateAvailable" "NewVersionName" $newStrVer

  ;if quiet mode, we now know there is a new version, we wrote it to the INI, so let's show ourselves
  strcmp $allparams "-quiet" 0 +3
   exec '"$EXEDIR\$EXEFILE"' ;having found no way to make the window re-apear, and be on top ; reboot
   quit
  ;if silentcheck mode, we now know there is a new version, we wrote it to the INI, so let's quit
  strcmp $allparams "-silentcheckonly" 0 +2   
   quit 
    
    
  ;Check if this project is now using a new Updater ;MUST BE DONE FIRST in this function! If updater.dat format chaged, checking for a new BaseURL will fuck up  
;  push "$EXEDIR\$EXEFILE" ;file
;  push "$newUpdaterVer" ;snap
;  call IsStampNewerThanFile
  push $newUpdaterVer ;see if new fileStamp is newer than old. Can't get filestamp from file, since possibly different timezone.
  push $updrSettingsUVer
  call IsNewStampNewer ;push new, than old stamp
  pop $0
  strcmp $0 "false" checkNewUpdater_CheckUpdateMode 0 ;if not newer, do nothing, else, replace
   !insertmacro GETLANGTEXT "MSG_UpdaterDisappear" "" ""
   strcpy $4 "$resultLangText"
   call promptToUpdate ;there is only one to update version and updater now
   strcmp $R5 "OK" +2   
    call onFailQuit    
  ;;Download new Updater.exe
  strcpy $curFileGetURL '$updrSettingsBaseURL\newupdater$maskExtension'
  Push $curFileGetURL ;this is used to replace \ with /
  Push "\"
  Push "/"
  Call StrRep
  Pop "$curFileGetURL" ;result
  strcpy $curFileTargetURL "$PLUGINSDIR\UpdaterNewexe.7z"
   ;inetc::get /CAPTION "Downloading new Updater..." /BANNER "Downloading $curFileGetURL" $curFileGetURL $curFileTargetURL
   inetc::get /CAPTION "$updrSettingsName Updater" /RESUME "Download failed. Try to resume?" /TRANSLATE "Downloading New Updater..." "Connecting ..." second minute hour s "%dkB (%d%%) of %dkB @ %d.%01dkB/s" "(%d %s%s remaining)" $curFileGetURL $curFileTargetURL /END
   ;If download failed, close program
   Pop $R0 ;Get the return value
   StrCmp $R0 "OK" +3
     Call downloadFailed
     goto endOfcheckNewUpdaterDat
  
  ;extract new updater
  SetOutPath "$PLUGINSDIR\" ;extract to cur folder in appdata
  Push "$PLUGINSDIR\UpdaterNewexe.7z" ;7zip source ; was .lzma
  Push "$PLUGINSDIR\deleme.tmp" ;tmpfile
  ExtractDllEx::extract
  Pop $R0
  StrCmp $R0 success +3
   messagebox mb_ok "Update data (newupdater$maskExtension) is corrupt. Please try again later."
   call OnFailQuit 
  ;rename "$PLUGINSDIR\orig.tmp" "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\UpdaterNew.exe" ;flakey as hell
  clearerrors
  copyfiles /SILENT /FILESONLY "$PLUGINSDIR\orig.tmp" "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\UpdaterNew.exe"
  iferrors 0 +3
   messagebox mb_ok "Update data (newupdater$maskExtension) could not be extracted. Please try again later."
   call OnFailQuit 

   ;Split path: Either do stuff here if there is Admin, or make UpdaterHelper do it, if there is not (This is done so support never needing UAC prompt when Software installed into AppData)
   call checkForAdmin
   strcmp $isAdmin "yes" checkNewUpdater_newUpdaterExe_retryUpdaterCopy checkNewUpdater_newUpdaterExe_LetUpdaterHelperDoIt
   ;
   ;Copy new updater as UpdaterNew.exe +write to Update.dat locally (Needs Admin)
   ;
 checkNewUpdater_newUpdaterExe_retryUpdaterCopy:
  clearerrors  
  copyfiles /SILENT /FILESONLY "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\UpdaterNew.exe" "$EXEDIR\UpdaterNew.exe"
  iferrors 0 +3
   messagebox mb_retrycancel "Can't update Updater! No write access to $EXEDIR?" IDRETRY checkNewUpdater_newUpdaterExe_retryUpdaterCopy
   quit
  ;new updater stamp is only put in the right place on a successful updater update (put in tmp until then)
  WriteINIStr "$EXEDIR\Updater.dat" "Tmp" "UpdaterStampTmp" $newUpdaterVer  
  exec "$EXEDIR\UpdaterNew.exe"  
  quit
    
 checkNewUpdater_newUpdaterExe_LetUpdaterHelperDoIt:  
  ;
  ;Let UpdaterHelper.exe: Copy new updater as UpdaterNew.exe +write to Update.dat locally (Needs Admin)
  ;   
  SetOutPath "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\"
  File "/oname=${UPDATER_HELPER_CUTENAME}" "UpdaterHelper.exe"
  execshell open "$APPDATA\PuchisoftDispatcher\$updrSettingsNameSafe_$updrSettingsGID\${UPDATER_HELPER_CUTENAME}" "updateUpdater¤$EXEDIR¤$newUpdaterVer¤"  
  quit
  ;END of New updater exe check
  
  
  checkNewUpdater_CheckUpdateMode: ;MUST BE AFTER NEW UPDATER CHECK
  ;First, let's check that this Pro/Corp Updater was actually genned by Pro/Corp GUI of Dispatcher (and not just copied from another project)
   ;all checked data is taken from server, so there is no mix-up. Also, we know we have the newest Updater, because that was verified above 
  !if ${PRODUCT_EDITION} != "Free"
    ;md5(0thMirrorURL+MagicKey)
    !if ${PRODUCT_EDITION} == "Pro"   
      md5dll::GetMD5String "$newFirstMirrorURLHRSWKHJ84378D"
    !endif
    !if ${PRODUCT_EDITION} == "Corp"   
      md5dll::GetMD5String "$newFirstMirrorURLOJG643FS57KMNC"
    !endif
    Pop $expectedPChecksum
    strcmp $newPChecksum $expectedPChecksum checkNewUpdater_okP
     !insertmacro WRITELN "Invalid Updater License!"
     !insertmacro WRITELN " Please ask the author to contact Puchisoft to resolve this issue." 
     call OnFail
     goto endOfcheckNewUpdaterDat
   checkNewUpdater_okP: 
  !endif
    
  ;Handle changes in Update Mode  
  strcmp $updrSettingsUType $newUType endOfcheckNewUpdaterDat ;no change, do nothing
  intcmp $updrSettingsUType 3 0 checkNewUpdater_ChangeInUMode_WasPatch 0 ;<3
  goto checkNewUpdater_ChangeInUMode_WasSync
  
  checkNewUpdater_ChangeInUMode_WasPatch:
  ;MessageBox MB_OKCANCEL "Was Patch"
  intcmp $newUType 3 +3 0 +3 ;is still patch (but different, so just compression toggle)
    strcpy $updrSettingsUType $newUType ;comp toggle requires nothing else
    goto endOfcheckNewUpdaterDat
   ;Changed to Sync - remember new settings, and restart upddater
   !insertmacro GETLANGTEXT "STATUS_ThisTimeSync" "" ""
   !insertmacro WRITELN "$resultLangText"
   strcpy $updrSettingsUType $newUType ;if compression was toggled too, we need to be aware of this     
   call modeChanged ;Full Recover is required too! Otherwise, next run will erronimously think it's up to date
   goto endOfcheckNewUpdaterDat
  
  checkNewUpdater_ChangeInUMode_WasSync:
  ;MessageBox MB_OKCANCEL "Was Sync"
  intcmp $newUType 3 0 +3 0 ;is still sync (but different, so just compression toggle)
    strcpy $updrSettingsUType $newUType ;comp toggle requires nothing else
    goto endOfcheckNewUpdaterDat
  ;Changed to Patch
  !insertmacro GETLANGTEXT "STATUS_NextTimePatch" "" ""
  !insertmacro WRITELN "$resultLangText"
   strcpy $updrSettingsUType $newUType  ;if compression was toggled too, we need to be aware of this
   call modeChanged
   goto endOfcheckNewUpdaterDat
         
  endOfcheckNewUpdaterDat:
FunctionEnd

Function modeChanged
clearerrors
  ;Prompt to update
  strcpy $4 ""
  call promptToUpdate
  call checkForAdmin_RebootIfNotAdmin  
  call prepareFullRecover ;silently switch to a Full Recover type of Syncing, no need to restart  
FunctionEnd

Function runUsrProg
   
   strcmp $updrSettingsExePath "" noRun
   ifsilent noRun ;don't do if silent
   
   strcmp $updrSettingsKillEXE "" dontLook
   strcpy $R0 "p0rk" ;BUG: THIS call doesn't actually return anything in R0 like it claims to!!
   FindProcDLL::FindProc "$updrSettingsKillEXE"   
   strcmp $R0 "1" noRun
   
   dontLook:
   ;Run their EXE
   SetOutPath $EXEDIR
   exec '"$EXEDIR\$updrSettingsExePath" $updrSettingsExeParams' ;Odd working directory, making fragile user apps sad
   ;execshell 'open' '"$EXEDIR\$updrSettingsExePath" $updrSettingsExeParams'
   noRun:
FunctionEnd

Function promptToUpdate ;$4 is either "" or specific to language ~"Updater will disappear" if updater Update   
    
   ;FindWindow $9 "" "$updrSettingsName Updater - [Puchisoft Updater ${PRODUCT_VERSION}]"
   ;MessageBox MB_OKCANCEL "$HWNDPARENT"
   ;SendMessage $HWNDPARENT 0x001c 0 0 
    strcpy $5 ""
    
  !if ${PRODUCT_EDITION} == "Free"  
   !insertmacro WRITESTATUS "Puchisoft Dispatcher: Freeware Edition [Non-Commercial Use Only]"
   #intcmp $updrSettingsUType 2 0 0 freeCheckSyncMode2 ;if patch mode, stay
   # strcpy $5 "$\n$\nThis is a Demo of Patch Mode. This Updater may not be distributed!" 
 freeCheckSyncMode2: 
   
  !else 
   !insertmacro GETLANGTEXT "STATUS_NewVersion" "" ""
   !insertmacro WRITESTATUS "$resultLangText"   
  !endif 
   
   strcmp $allparams "-update" goAheadWUp ;auto-yes (NOTE: this is also set by syncModeVerifyMD5OfDownloadedFile - make sure that keeps working)
   strcmp $bFullRecover 1 goAheadWUp
   strcmp $updrSettingsStrVer $newStrVer dontMentionVersion ;Don't mention version if there is no change in verstion string
     !insertmacro GETLANGTEXT "MSG_NewVersion" "" ""     
     MessageBox MB_OKCANCEL "$resultLangText$4$5" /SD IDOK IDOK goAheadWUp ;!Lang ;from version $updrSettingsStrVer
      goto dontdoit
dontMentionVersion:
     !insertmacro GETLANGTEXT "MSG_NewVersionNV" "" ""
     MessageBox MB_OKCANCEL "$resultLangText$4$5" /SD IDOK IDOK goAheadWUp ;!Lang
      goto dontdoit
 dontdoit:
  strcpy $R5 "CANCEL"
  goto endOfPrompt
 goAheadWUp:
  strcmp $updrSettingsKillEXEOnlyIfNeeded 1 +2 ;close software instantly, unless it's never closed until needed 
    call promptToClose 
  strcpy $R5 "OK"  
 endOfPrompt: 
FunctionEnd

Function downloadFailed
   strcmp $R0 "File Open Error" fileOpenErr
   strcmp $R0 "Terminated" silentfailure
   strcmp $R0 "Cancelled" silentfailure
   StrCmp $R0 "File Not Found (404)" fileNotFound
   strcmp $R0 "SendRequest Error" 0 genericfailure
   goto genericfailure   
   
   fileOpenErr:
   FileClose $md5listFile
   !insertmacro GETLANGTEXT "MSG_FileNotWritable" "$curFileTargetURL" ""
   MessageBox MB_OK|MB_ICONEXCLAMATION "$resultLangText" /SD IDOK ;!Lang
   goto silentfailure
   
   fileNotFound:
   ;If we are in FullRecover mode, we can chek if Sync.var is "X". Only that means Full Recover is disallowed!
   ;strcmp $bFullRecover 1 +4 ;files not existing in recover mode, 99% means that it's off
    MessageBox MB_YESNO "Download failed [$curFileGetURL]! The required file is not on the server. The server is probably under maintenance. Try again later. If this error occurs multiple times, try a Full Recover. If this is the first time, just click 'No' and try updating again later.$\n$\nTry a Full Recover now?" /SD IDNO IDNO +2 ;!Lang
    call rebootIntoRecoveryMode
    ;goto +2
   ;MessageBox MB_OK "File Recovery failed.$\n $updrSettingsName does not allow File Recovery. Please re-install."   
   goto silentfailure
   
   genericfailure:
   MessageBox MB_OK|MB_ICONEXCLAMATION "Download failed [$curFileGetURL]! Check your internet connection or try again later. $\n(Error: $R0)" ;!Lang
   goto silentfailure
   
   silentfailure:
   ;Call runUsrProg
   call onFail
FunctionEnd
Function downloadFailedAllowRetry
   strcpy $R1 "DontRetry"
   strcmp $R0 "File Open Error" fileOpenErr
   strcmp $R0 "Terminated" silentfailure
   strcmp $R0 "Cancelled" silentfailure
   StrCmp $R0 "File Not Found (404)" fileNotFound
   strcmp $R0 "SendRequest Error" 0 genericfailure
   goto genericfailure
   
   fileOpenErr:
   FileClose $md5listFile
   !insertmacro GETLANGTEXT "MSG_FileNotWritable" "$curFileTargetURL" ""
   MessageBox MB_OK|MB_ICONEXCLAMATION "$resultLangText" /SD IDOK ;!Lang
   goto silentfailure
   
   fileNotFound:
   ;If we are in FullRecover mode, we can chek if Sync.var is "X". Only that means Full Recover is disallowed!
   ;strcmp $bFullRecover 1 +4 ;files not existing in recover mode, 99% means that it's off
    MessageBox MB_YESNO "Download failed [$curFileGetURL]! The required file is not on the server. The server is probably under maintenance. Try again later. If this error occurs multiple times, try a Full Recover. If this is the first time, just click 'No' and try updating again later.$\n$\nTry a Full Recover now?" /SD IDNO IDNO +2 ;!Lang
    call rebootIntoRecoveryMode          
   goto silentfailure
   
   genericfailure:
   messagebox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Download failed! Check your internet connection or try again later.$\n$\n(File: $curFileGetURL)$\n(Error: $R0)" /SD IDCANCEL IDRETRY retry ;!Lang
   goto silentfailure
   
   retry:
   strcpy $R1 "Retry"
   goto dlend
   
   silentfailure:
   ;Call runUsrProg
   call onFail
   goto dlend ;does this happen?
   dlend:
FunctionEnd


Function PromptToClose
   push $R0 ;return of looky for proc
   push $R3 ;index
   push $R4 ;cur KillEXE Name
   push $R5 ;happy comma/space-seperated list of killEXEs
   push $R6 ;bolHasSomethingBeenClosed
   
   ;this function is called right before putting files into place, as well as on no-write access errors before that
    ;messagebox MB_OKCANCEL "all KillEXE: [$updrSettingsKillEXE]"
   strcmp $updrSettingsKillEXE "" noMorelookyForProc    
   
   Push $updrSettingsKillEXE ;this is used to replace \ with /
   Push ","
   Push ", "
   Call StrRep
   Pop "$R5" ;result
   
   strcpy $R6 0 ;nothing killed yet
   
   strcpy $R3 0 ;start loop index
 promptToClose_NextKillEXE:
   intop $R3 $R3 + 1
   clearerrors
   ${WordFind} $updrSettingsKillEXE "," "E+$R3" $R4 ;put current killEXE into R4
   iferrors 0 promptToClose_FindIt ;iferrors: end of list or list of one...
     strcmp $R3 1 +2 ;if this is the first item in the non-blank list, not done yet!
     goto noMorelookyForProc ;else, done
    strcpy $R4 $updrSettingsKillEXE ;this is the first item in a list of one, so just copy the whole thing into what we are cur killing         
   
 promptToClose_FindIt:
    ;messagebox MB_OKCANCEL "CurKillEXE: [$R4]"  
   ;make sure program isn't running before asking to close
   FindProcDLL::FindProc "$R4" ;call here ruturns r0 like it should just fine   
   strcmp $R0 "1" 0 promptToClose_NextKillEXE
      
      
   strcmp $R6 1 promptToClose_NoMsg ;if something was already closed, don't ask again, nuke it all
    !insertmacro GETLANGTEXT "MSG_MustClose" "$R5" ""   
    messagebox MB_OKCANCEL "$resultLangText" IDOK +2 ;no silinet ID, because this might happen on QuietCheck; what? No it couldn't!
    quit
promptToClose_NoMsg:
    
   strcpy $R6 1 ;remember that something has now been killed 
   
   ;kill by exe name
   KillProcDLL::KillProc "$R4"
   sleep 1000 ;sometimes needed for windows to acknoledge process is gone, ow users might see the prompt when it's not needed
   strcpy $bEXEWasTerminated "1" ;at least one of them was, which means the Updater shouldn't give up
   
   ;strcmp $R4 $updrSettingsKillEXE noMorelookyForProc ;if the result is the whole string, there are no more killEXEs ; this must be at the end to support a single killEXE   
   goto promptToClose_NextKillEXE

 noMorelookyForProc:   
   pop $R6
   pop $R5
   pop $R4
   pop $R3
   pop $R0
FunctionEnd

