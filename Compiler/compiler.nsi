;Setcompressor /solid lzma
!system "MakeDataIncl.exe"
!include "installer_includes.nsh"              
!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "DebugBuild"
!endif
!include WinMessages.nsh
;!ifndef PRODUCT_EDITION ;this is always defined by Installer_Includes now, which gets it from Dispatcher.dat, set by MakeEdition
;  !define PRODUCT_EDITION "Pro" ;Free, Pro, Corp
;!endif

!if ${PRODUCT_EDITION} == "Free"
 !define PRODUCT_NAME "Dispatch Compiler: Freeware Edition ${PRODUCT_VERSION}"
!endif
!if ${PRODUCT_EDITION} == "Pro"
 !define PRODUCT_NAME "Dispatch Compiler: Professional Edition ${PRODUCT_VERSION}"
!endif
!if ${PRODUCT_EDITION} == "Corp"
 ;!define PRODUCT_NAME "Dispatch Compiler: Corporate Edition ${PRODUCT_VERSION}"
 !define PRODUCT_NAME "Dispatch Compiler: Open Source Edition ${PRODUCT_VERSION}" ;OpenSourceEdition
!endif
Caption "${PRODUCT_NAME}" ;// August 6, 2007
SubCaption 3 " " ;Gets rid of stupid "Installing..." addon title
SubCaption 4 " " ;Gets rid of stupid "Installing..." addon title
BrandingText "www.puchisoft.com"
OutFile "..\Data\Compiler.exe"
;AutoCloseWindow True
InstallDir "$EXEDIR"
;Icon "${NSISDIR}\Contrib\Graphics\Icons\orange-install.ico"
icon ..\Updater\cog2.ico
RequestExecutionLevel admin
!include "WordFunc.nsh" ;aka. String parser ;)
!insertmacro WordFind
!include "FileFunc.nsh" ;;only for GetTime
!insertmacro GetFileAttributes
!insertmacro GetTime

AutoCloseWindow true
ShowInstDetails show ;nevershow ;hide
XPStyle on
SetFont "Verdana" 8


;!include "WinMessages.nsh"

;Page directory
;Page instfiles

var copySource
var copyTarget

var PRODUCT_NAME
var PROJ_FOLDER
var OUT_FOLDER
var INT_VERSION_NEW
var VERSION_NEW
var FOLDER_NEW
var STATUS_NEW

var INT_VERSION
var VERSION
var FOLDER_OLD
var STATUS_OLD

var INT_VERSION_INTERMEDIATE

var patchMapFullPath
var patchMapTrimPath

var patchRecoverModeAllowed

var maskExtension

var pudPath ;path to .pud ini file
var SNAP_NEW
var SNAP_CUR
var snapTmp ;tmp used when making snapshots
var excl_itt
var excl_curStr
var PATCH_NAME
var tmp0 ;used by Patch mode, since Snap function is called, and Snap function messes with normal variables
var tmp1
var tmp2
var tmp3
var tmp4
var tmp5
var tmp6
;var tmp7
var tmp8
var tmp9

var intdebug

var installer_icopath

var allparams
var nPath ;nsis path for making installers (passed via MMF, user picked)
var SEARCHDIR
var snapdest ;where to make snap file to
var snapMode ;snp (local, for proj) vs Snapshot (for WWW Sync mode)
var snapFile
var snapCompressToPath

var fileSource ;for singlefilecompress
var fileDest

var ftp_url
var ftp_url_TknCount
var ftp_url_bHasUserPass ;needed to fix @ in username bug
var ftp_url_userPass ;needed to fix @ in username bug
var ftp_path
var ftp_pathOrig
var ftp_ListFile ;file handle variable
var ftp_ListPath ;location of file
var ftp_intFilesToUpload ;for progress bar

;var cLogFile
var username
var password

#for only uploading changed files to FTP
var uploadedSnapshot_Prev_PathOrig #location
var uploadedSnapshot_Prev_Path #location
var uploadedSnapshot_Prev #file handler
var uploadedSnapshot_New_Path
var uploadedSnapshot_New
var onlyUploadChangedFiles

;var hasCancelled
var progressBarPos

var logSendMsgHndle

function StartDispatcherReleaseLogOnce
  FindProcDLL::FindProc "DispatcherReleaseLog.exe" ;ruturns r0   
  strcmp $R0 "1" +3 ;0=NotFound, 1=Found
    exec "$EXEDIR\DispatcherReleaseLog.exe"
    sleep 1000
functionEnd

!macro WRITELN TOWRITE
 ;FileWrite $cLogFile " ${TOWRITE}$\r$\n"
 
 ;start GUI Log if not started yet
 ;call StartDispatcherReleaseLogOnce
 
 ;Set EDIT box of MMF2 Gui Log to current line
; FindWindow $logSendMsgHndle "Mf2MainClassTh" "Dispatcher Release Log"  
; FindWindow $logSendMsgHndle "Mf2EditClassTh" "" $logSendMsgHndle
; FindWindow $logSendMsgHndle "ListBox" "" $logSendMsgHndle	
 SendMessage $logSendMsgHndle ${LB_ADDSTRING} 0 "STR:${TOWRITE}"
 ;FileClose $cLogFile 
 ;copyfiles /SILENT /FILESONLY "$EXEDIR\compiler.log" "$EXEDIR\compiler-r.log" ;allow GUI to read log 
 ;FileOpen $cLogFile "$EXEDIR\compiler.log" a
 ;FileSeek $cLogFile 0 END
!macroend

!macro REMOVEUPDATER DIR
 !insertmacro WRITELN "Removing Updater from: ${DIR}"
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Removing Updater from folder...$\r$\nPlease wait...` /sub `$\r$\n$\r$\n $copyTarget...` /h 0 /pos $progressBarPos /max 50 /can 0 /end
 clearerrors
 delete "${DIR}\Updater.exe"
 delete "${DIR}\Updater.dat"
 delete "${DIR}\Updater.bmp"
 delete "${DIR}\UpdaterLicense.txt"
 iferrors 0 +3
  push "Can't delete ${DIR}\Updater.*"
  call failQuitMsg
!macroend

!macro FTP_URL_FIX_USERPASS FTPURL ;${FTPURL} will be fixed, turning @s in User/Pass into %40
 !define MacroID ${__LINE__}
 ;strcpy ${FTPURL} "ftp://user1@myftp.com:password@myftp.com/myfile.txt" 
 ;strcpy ${FTPURL} "ftp://user:pass@myftp.com/myfile.txt"
 ;strcpy ${FTPURL} "ftp://myftp.com/myfile.txt"
 
 ;Take the User/Pass out of the URL (into $ftp_url_userPass), and later replace @ with %40 there only (to Fix Usern@me bug)
 strcpy $ftp_url_userPass "${FTPURL}"
 ${WordFind} $ftp_url_userPass "@"  "*" $ftp_url_bHasUserPass
 strcmp $ftp_url_bHasUserPass $ftp_url_userPass macroUsrNameFix_noUserPass_${MacroID} ;No @ in URL anywhere
 ${WordFind} $ftp_url_userPass "@"  "-1{" $ftp_url_userPass ;Only keep everything before the LAST @ 
   
 ;Now we remove the User/Pass combo from the URL, replace with ""
 Push $ftp_url_userPass ;this is used to replace 1st push with 2nd
 Push '@'
 Push '%40'
 Call StrRep
 Pop "$ftp_url_userPass" ;result
 
 ${WordFind} ${FTPURL} "@"  "-1}" ${FTPURL} ;ftp_url is only right part, after last @
 strcpy ${FTPURL} "$ftp_url_userPass@${FTPURL}" ;ftp_url is altered user:pass string + @ + ftp_url(right part)
 
 ;messagebox mb_ok "yes u/p [${FTPURL}]" 
 goto macroUsrNameFix_end_${MacroID}
 
 macroUsrNameFix_noUserPass_${MacroID}:
 ;messagebox mb_ok "No User/Pass [${FTPURL}]"
 macroUsrNameFix_end_${MacroID}:
 !undef MacroID
!macroend

Function failQuitMsg
 Pop $0
 !insertmacro WRITELN $0
 ;FileWrite $cLogFile "$0$\r$\n" 
 ;FileClose $cLogFile
 ;fatel errors
 clearerrors
 delete "$EXEDIR\compiler.start"
 ;delete "$EXEDIR\compiler.success"
 FileOpen $1 "$EXEDIR\compiler.fail" w ;reportFailure to GUI
 FileWrite $1 "Fail"
 FileClose $1
 iferrors 0 +2
  MESSAGEBOX MB_OK|MB_ICONSTOP "Could not write error notice at $EXEDIR. You are about to see an invalid Success screen." 
 RMDir /r /REBOOTOK "$PLUGINSDIR"
 quit
FunctionEnd

Function reportStart
 ;fatel errors
 clearerrors
 delete "$EXEDIR\compiler.fail"
 ;delete "$EXEDIR\compiler.success"
 FileOpen $1 "$EXEDIR\compiler.start" w
 FileWrite $1 "$tmp0" ;Write Release Type + Proj Name into Start file
 FileClose $1
 iferrors 0 +2
  MESSAGEBOX MB_OK|MB_ICONSTOP "Could not write error notice at $EXEDIR." 
FunctionEnd

Function reportSuccess 
 ;fatel errors
 !insertmacro WRITELN "@@SUCCESS" ;special message that GUI Log knows to mean success
 clearerrors
 delete "$EXEDIR\compiler.fail"
 delete "$EXEDIR\compiler.start" 
 iferrors 0 +2
  MESSAGEBOX MB_OK|MB_ICONSTOP "Could not write error notice at $EXEDIR." 
FunctionEnd

Function checkIfNewestVersionAltered
 iffileexists "$PROJ_FOLDER\Snapshots\$INT_VERSION_NEW.snp" 0 checkIfNewestVersionAltered_first
  md5dll::GetMD5File "$PROJ_FOLDER\Snapshots\$INT_VERSION_NEW.snp"
  Pop $0
  md5dll::GetMD5File "$PROJ_FOLDER\Snapshots\tmp$INT_VERSION_NEW.snp"
  Pop $1
  strcmp $0 $1 checkIfNewestVersionAltered_ok
   push "ERROR: The latest version ($INT_VERSION_NEW) has previously been released with different content! In Patch Mode, you may not change the content of a version's folder once it has been released. If you can't restore this folder, please add a new version and then set this version's Status to Retired (Sync)."
   call failQuitMsg
 checkIfNewestVersionAltered_first:
  copyfiles /SILENT /FILESONLY "$PROJ_FOLDER\Snapshots\tmp$INT_VERSION_NEW.snp" "$PROJ_FOLDER\Snapshots\$INT_VERSION_NEW.snp"  
 
 checkIfNewestVersionAltered_ok:  
FunctionEnd
Function checkIfOldVersionAltered
 strcpy $R0 "" ;no action
 iffileexists "$PROJ_FOLDER\Snapshots\$INT_VERSION.snp" 0 checkIfOldVersionAltered_first
  md5dll::GetMD5File "$PROJ_FOLDER\Snapshots\$INT_VERSION.snp"
  Pop $0
  md5dll::GetMD5File "$PROJ_FOLDER\Snapshots\tmp$INT_VERSION.snp"
  Pop $1
  strcmp $0 $1 checkIfOldVersionAltered_ok ;if Folder Contents Altered     
   strcmp $patchRecoverModeAllowed "1" checkIfOldVersionAltered_revertToSync ;if File Recover is allowed, we can revert to sync this one time, and move on
    push "ERROR: Old version $INT_VERSION ($VERSION) was not originally released with the content found in: $FOLDER_OLD! In Patch Mode, you may not change the content of a version's folder once it has been released. If you can't restore this folder, please set the version's Status to Retired."
    call failQuitMsg
 checkIfOldVersionAltered_revertToSync:
  strcpy $R0 "SyncIt" ;revert to Sync mode this one time
  !insertmacro WRITELN "WARNING: Old version $INT_VERSION ($VERSION) was not originally released with the content found in: $FOLDER_OLD!"
  !insertmacro WRITELN " In Patch Mode, you may not change the content of a version's folder once it has been released."
  !insertmacro WRITELN " The Status of this version has fallen back to Retired (Sync) for this operation only."
  goto checkIfOldVersionAltered_ok
    
 checkIfOldVersionAltered_first:
  copyfiles /SILENT /FILESONLY "$PROJ_FOLDER\Snapshots\tmp$INT_VERSION.snp" "$PROJ_FOLDER\Snapshots\$INT_VERSION.snp"  
 
 checkIfOldVersionAltered_ok:  
FunctionEnd

Function Snap
 !insertmacro WRITELN ">Generating Version $7 Snapshot for Patch Mode..."
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Generating Version $7 Snapshot for Patch Mode.$\r$\nPlease wait...` /sub `$\r$\n$\r$\n Preparing...` /h 0 /pos $progressBarPos /max 50 /can 1 /end 
 strcpy $snapMode "snp"
 call findfile0
FunctionEnd

Function succeedCleanupAndQuit 
 delFailFile:
  delete "$EXEDIR\compiler.fail" ;delete .fail notice, since we didn't fail NOR crash ;)
 IfFileExists "$EXEDIR\compiler.fail" delFailFile
 quit 
FunctionEnd

Function .onInit 
 Call GetParameters
 Pop $allparams
 ;setsilent silent
 ;InitPluginsDir ;done after ShellOpen param

 
 ;This is our EXEProxy, in the same exe as the compiler (Originally done to get AVG to fuck off; also saves space)
 ;We copy the Compiler.exe as LZMA/CompressFile into a tmp dir, run ourselves, and then let CompressFile_.exe call us, who pass it on to LZMA_.exe
 ;This has the end of effect of making no windows pop up en masse ;)
 strcmp $EXEFILE "LZMA.exe" lauchRealOne
 strcmp $EXEFILE "CompressFile.exe" lauchRealOne
 goto goOn
 lauchRealOne:
 ${WordFind} $EXEFILE "." "+1" $1 
 nsExec::ExecToLog '$1_.exe $allparams'
 ;execshell open $EXEDIR
 ;MessageBox MB_OK '$1_.exe $allparams' 
 quit ;Issue: By finishing abnormally early, we return an error! Be sure to ignore this error, and just check if the files were compressed like they were suppose to (auto-done by trying to copy these files)
 goOn:
FunctionEnd

Function checkForCancelAndQuit ;this also increase progress bar in loopy way
 ;call checkForCancelAndQuit_IgnoreProgressBar
 ;not cancelled
 call increaseAndLoopProgressBar 
FunctionEnd

;;;OLD - No GUI, can't click Quit (didn't work anyway)
;Function checkForCancelAndQuit_IgnoreProgressBar ;this just checks for quit
; ;nxs::HasUserAborted /NOUNLOAD ;WARNING: Calling this fucks up $R0 and co variables. Maybe even $0. This may not be done in findfile0 snap routine
; pop $hasCancelled
; strcmp $hasCancelled "1" 0 +3
;  push "Aborted by User."
;  call failQuitMsg
 ;not cancelled
;FunctionEnd

Function increaseAndLoopProgressBar ;No need for this anymore? Used by FTP? no, right?
 intop $progressBarPos $progressBarPos + 1
 intcmp $progressBarPos 50 +2 +2 0 ;>50 then reset to 0
  strcpy $progressBarPos 0
 ;nxs::Update /NOUNLOAD /pos $progressBarPos ;WARNING: Calling this fucks up $R0 and co variables. Maybe even $0. This may not be done in FTP routine, nor findfile0 snap routine
FunctionEnd

Function .onGUIInit
 strcpy $progressBarPos 0
 delete "$EXEDIR\compiler.login"
 delete "$EXEDIR\compiler.pcheck"
 clearerrors
 FileOpen $1 "$EXEDIR\compiler.fail" w ;assume failure at first, so if crash, it is noticed as a fail; on success, delete .fail
 FileWrite $1 "Fail"
 FileClose $1
 iferrors 0 +3 ;check if files can be written
  MESSAGEBOX MB_OK|MB_ICONSTOP "FAILURE: Can't write files in $EXEDIR [Params: $allparams]"
  quit
 
 delete "$EXEDIR\NSIS.log"
 ;FileOpen $cLogFile "$EXEDIR\compiler.log" a
 ;FileSeek $cLogFile 0 END
 
 ;get handle to log GUI display
 FindWindow $logSendMsgHndle "Mf2MainClassTh" "Dispatcher Release Log"  
 FindWindow $logSendMsgHndle "Mf2EditClassTh" "" $logSendMsgHndle
 FindWindow $logSendMsgHndle "ListBox" "" $logSendMsgHndle
 
 ${WordFind} $allparams "¤" "+1" $0
 strcmp $0 "shellopen" shellopen ;called to open things in Firefox or whatever
  InitPluginsDir
 StrCmp $0 "nukedir" nukedir
 StrCmp $0 "copyfolder" copyfolder
 StrCmp $0 "release" release
 StrCmp $0 "releaseStart"   releaseStart ;report to GUI Log
 StrCmp $0 "releaseSuccess" releaseSuccess ;report to GUI Log
 StrCmp $0 "writeln" ext_writeln ;do a write line, so Dispatcher.exe can talk to logGUI
 StrCmp $0 "sleep" ext_sleep 
 StrCmp $0 "patch" zpatch
 StrCmp $0 "makeInstaller" makeInstaller 
 StrCmp $0 "newproj" newproject
 strcmp $0 "snapSync" snapSync ; for sync mode
 strcmp $0 "snapSyncComp" snapSyncComp ; for sync mode+Compression
 strcmp $0 "snapPatch" snapPatch 
 strcmp $0 "removeUpdater" removeUpdater ; for when releasing the newest version to its own folder
 strcmp $0 "ftpall" ftpall ;upload to all given FTP urls
 strcmp $0 "singleftp" singleftp ; for uploading Installer
 strcmp $0 "singlefilecompress" singlefilecompress ; for Updater.exe and Updater.dat (since Jan01_2k9)
 strcmp $0 "makestamp" makeStamp
 strcmp $0 "loginCheck" loginCheck ;for Pro/Corp Dispatcher accounts
 strcmp $0 "registerProject" registerProject ;reg proj with puchisoft
 strcmp $0 "getPChecksum" getPChecksum
 strcmp $0 "testStatsURL" testStatsURL
 goto nocmdln
 
 ext_writeln:
  ${WordFind} $allparams "¤" "+2*}" $tmp0 ;put 2nd and all futher params in
  !insertmacro WRITELN $tmp0
  goto zend
  
 ext_sleep: ;NOT USED
  ;${WordFind} $allparams "¤" "+2" $tmp0 ;
  ;sleep $tmp0
  goto zend
 
 releaseStart:
  ${WordFind} $allparams "¤" "+2*}" $tmp0 ;put 2nd and all futher params in
   
   call CreateGUID 
   pop $tmp1  
   strcpy $tmp0 "$tmp0¤$tmp1" ;attach random GUID to Start, so LogGUI knows the same project starting to be released twice in a row to a new release
 
  call reportStart  ;overwrites previous compiler.start
  call StartDispatcherReleaseLogOnce  
  goto zend
  
 releaseSuccess:
  call reportSuccess
  goto zend
 
 testStatsURL: ;called by GUI Advanced Tab
 ${WordFind} $allparams "¤" "+2" $tmp0 ;statsURL
 inetc::post "name=MyTestApp&gid=0B3D416D-0083-416C-AEB4-C36B78CA8ACB&old=v1.0&new=v1.2b" /SILENT "$tmp0" "$PLUGINSDIR\reply0.tmp"
 Pop $R0
 messagebox mb_ok 'Posted "name=MyTestApp old=v1.0 new=v1.2b" to given url: $tmp0 $\nResult: $R0'
 
 goto zend
 
 getPChecksum:
 ${WordFind} $allparams "¤" "+2" $tmp0 ;0th MirrorURL
 
 !if ${PRODUCT_EDITION} != "Free" 
 ;Generate expected Checksum to ensure this .dat file was made by Dispatcher MMF GUI (prevent copying Pro updater.exe over Free)
 ;md5(0thMirrorURL+MagicKey)
 !if ${PRODUCT_EDITION} == "Pro"   
  md5dll::GetMD5String "$tmp0HRSWKHJ84378D"
 !endif
 !if ${PRODUCT_EDITION} == "Corp"   
  md5dll::GetMD5String "$tmp0OJG643FS57KMNC"
 !endif
 Pop $tmp0 
 !endif
 strcpy $tmp0 "P=$tmp0"
  
 clearerrors
 FileOpen $1 "$EXEDIR\compiler.pcheck" w ;get ready to write success status
   iferrors 0 +3 ;check if files can be written
   MESSAGEBOX MB_OK|MB_ICONSTOP "FAILURE: Can't write files in '$EXEDIR' [P]"
   quit   
 FileWrite $1 $tmp0
 FileClose $1  
 goto zend
 
 registerProject:
 
 ;OpenSourceEdition: NoOp
 
 goto zend
 
 
 loginCheck:
 ${WordFind} $allparams "¤" "+2" $username ;username
 ${WordFind} $allparams "¤" "+3" $password 
 clearerrors
 FileOpen $1 "$EXEDIR\compiler.login" w ;get ready to write success status  
   iferrors 0 +3 ;check if files can be written
   MESSAGEBOX MB_RETRYCANCEL|MB_ICONSTOP "FAILURE: Can't write files in '$EXEDIR' [Login]" IDRETRY loginCheck 
   quit
 
 ;OpenSourceEdition: Every login is cool!

 FileWrite $1 "OK"
 FileClose $1
 goto zend
 
 singleftp:
 singleFTP_retry: ;we change the $ftp_url variable, maybe, so reset
 ${WordFind} $allparams "¤" "+2" $ftp_pathOrig
 ${WordFind} $allparams "¤" "+3" $ftp_url
 !insertmacro WRITELN " Uploading: $ftp_pathOrig"
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Uploading...$\r$\nPlease wait...` /sub `$\r$\n Uploading: $ftp_pathOrig ...$\r` /h 0 /pos $progressBarPos /max 50 /can 0 /end
  ;Inetc::put "$ftp_url" "$ftp_pathOrig" /end ;fails to change dir properly on some FTP servers
  ;curl.exe --ftp-create-dirs -u "me@my.com:x" -T "R:\MyStuff\Coding\Projects\Dispatcher\Source\Contrib\cogs.bmp" "ftp://localhost/Updates/MySoftware/BS/cogs.bmp"  
  
  !insertmacro FTP_URL_FIX_USERPASS $ftp_url ;fixes $ftp_url up to fix usern@me bug
  
  nsExec::ExecToStack '"$EXEDIR\..\Contrib\curl.exe" -T "$ftp_pathOrig" "$ftp_url" --ftp-create-dirs'    
  Pop $2 
  StrCmp $2 "0" zend  
   Pop $2  
   ${WordFind} $2 ") " "+1}" $2
   strcpy $2 $2 -2
  !insertmacro WRITELN "  File upload failed ($2): $ftp_url. Retry? NOTE: To answer this question, look for a message box behind this window! Sorry."  
  MessageBox MB_YESNO "File upload failed ($2): $ftp_url. Retry?" IDYES singleFTP_retry 
 goto zend
 
 singlefilecompress: ;compress a single file - Not efficient at all, don't use more than a few times in a row if you care about speed
 
 ${WordFind} $allparams "¤" "+2" $fileSource
 ${WordFind} $allparams "¤" "+3" $fileDest
 !insertmacro WRITELN "Compressing: $fileSource ..."
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Compressing...$\r$\nPlease wait...` /sub `$\r$\n Compressing: $fileSource ...$\r` /h 0 /pos $progressBarPos /max 50 /can 0 /end
 
 SetOutPath "$PLUGINSDIR\"
   File "_plugin\CompressFile_.exe"
   File "_plugin\lzma_.exe" ;real lzma
   copyfiles /SILENT /FILESONLY "$EXEDIR\$EXEFILE" "$PLUGINSDIR\LZMA.exe"
   copyfiles /SILENT /FILESONLY "$EXEDIR\$EXEFILE" "$PLUGINSDIR\CompressFile.exe"
   
   copyfiles /SILENT /FILESONLY "$fileSource" "$PLUGINSDIR\orig.tmp"
   
   iferrors 0 +3
    push "Can't read file: $fileSource "
    call failQuitMsg
   
   execwait '$PLUGINSDIR\CompressFile.exe tmp.tmp orig.tmp'
   clearerrors
   
   delete "$fileDest" ;The following CopyFiles implies overwriting, but it doesn't seem to work always, so just to make sure, let's delete first
   iferrors 0 +3
    push "Can't delete file: $fileDest "
    call failQuitMsg
   
   copyfiles /SILENT /FILESONLY "$PLUGINSDIR\tmp.tmp" "$fileDest"
   iferrors 0 +3
    push "Can't overwrite file: $fileDest "
    call failQuitMsg
 
 goto zend
 
 makeInstaller:
 !insertmacro WRITELN "Creating installer..."
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Creating installer...$\r$\nPlease wait...` /sub `$\r$\n$\r$\n Compressing...` /h 0 /pos $progressBarPos /max 50 /can 1 /end
 ${WordFind} $allparams "¤" "+2" $pudPath
 ${WordFind} $allparams "¤" "+3" $nPath ;nsis path
 
 ;Read in all the options the user wanted !!Warning, since we're out of variables here and we didn't really need to do this yet, some vars are loaded in ~2 code blocks down
 readinistr $0 $pudPath "Installer" "script";
 readinistr $1 $pudPath "Installer" "exepath";
 readinistr $2 $pudPath "Installer" "website";
 readinistr $3 $pudPath "Installer" "license";
 readinistr $4 $pudPath "Installer" "programGroup";
 readinistr $5 $pudPath "Installer" "outPath";
 readinistr $6 $pudPath "Installer" "bDesktopShortcut"; More below!
 readinistr $7 $pudPath "Installer" "bRunExe";
 readinistr $8 $pudPath "Main" "PName";
 readinistr $9 $pudPath "Versions" "0" 
 readinistr $tmp2 $pudPath "Release" "pathRelease"
 readinistr $installer_icopath $pudPath "Customize" "EXEPath" 
 
 clearerrors                     ;Try to open the user-picked Install script
 fileopen $tmp0 $0 r
 iferrors 0 makeInstallerGotScript
  fileclose $tmp0
  strcpy $0 "$EXEDIR\..\InstallScripts\$0.nsi"
  fileopen $tmp0 $0 r
  iferrors 0 makeInstallerGotScript
   fileclose $tmp0
   Push "Could not find installer script: $0"
   call failQuitMsg
 
 makeInstallerGotScript:
 fileclose $tmp0
 ${WordFind} $9 "¤§" "+2" $tmp1 ;ver Str
 
 strcpy $tmp0 ""
 strcmp $1 "" +2 ;exepath
  strcpy $tmp0 '$tmp0/DDISPATCHER_EXEPATH="$1" '
 strcmp $4 "" +2 ;programGroup
  strcpy $tmp0 '$tmp0/DDISPATCHER_STARTMENUGROUP="$4" '
 strcmp $2 "" +2 ;website
  strcpy $tmp0 '$tmp0/DDISPATCHER_WEBSITE="$2" '
 strcmp $3 "" +2 ;license
  strcpy $tmp0 '$tmp0/DDISPATCHER_LICENSE="$3" '
 strcmp $6 "1" 0 +2 ;desktop shortcut
  strcpy $tmp0 '$tmp0/DDISPATCHER_BDESKTOPSHORTCUT="$6" '
 strcmp $7 "1" 0 +2 ;runExe
  strcpy $tmp0 '$tmp0/DDISPATCHER_BRUNEXE="$7" '
 
 ;Additional user-picked variable settings here, read them all into 6 (which is not read again, like maybe 7+) 
 readinistr $6 $pudPath "Installer" "bUpdaterShortcut" 
 strcmp $6 "1" 0 +2 ;installer shortcut
  strcpy $tmp0 '$tmp0/DDISPATCHER_BUPDATERSHORTCUT="$6" ' 
  
 ;pick an nsis to use
 clearerrors
 FileOpen $tmp9 "$nPath\makensis.exe" r
 FileClose $tmp9
 iferrors 0 +2 ;supplied path has NSIS, keep it
  strcpy $nPath "$EXEDIR\..\Contrib\NSIS"
  
 !insertmacro WRITELN " Using NSIS: $nPath"
 
 ;warning: /D params may not have a trailing \ before " end (will nuke formatting), ala: http://forums.winamp.com/showthread.php?threadid=292190
 strcpy $0 '"$nPath\makensis.exe" /V1 /O"$EXEDIR\NSIS.log" $tmp0/DDISPATCHER_RELEASEPATH="$tmp2" /DDISPATCHER_VERSION="$tmp1" /DDISPATCHER_INSTOUTPATH="$5" /DDISPATCHER_ICOPATH="$installer_icopath" /DDISPATCHER_NAME="$8" "$0"' 
 Push $0 ;this is used to replace 1st push with 2nd
 Push '\"'
 Push '"'
 Call StrRep
 Pop "$0" ;result
 ;make location of nsis constomizable
 nsExec::ExecToLog '$0' 
 pop $0
  call checkForCancelAndQuit
 strcmp $0 "0" zend
 ExecShell "open" "$EXEDIR\NSIS.log"
 Push "Creating installer failed with error code: $0"
 call failQuitMsg
 goto zend
 
 shellopen: ;used by Mirror Properties's Test btn
 ${WordFind} $allparams "¤" "+2" $tmp0 ;URL, or whatever
 ExecShell "open" "$tmp0"
 goto zend
 
 ftpall:
 !insertmacro WRITELN ">Uploading to mirrors via FTP..."
 !insertmacro WRITELN " Generating list of files to upload..." 
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Uploading to FTP....$\r$\nPlease wait...` /sub `$\r$\n$\r$\n $copyTarget...` /h 0 /pos $progressBarPos /max 50 /can 1 /end
 ${WordFind} $allparams "¤" "+2" $OUT_FOLDER ;WWW folder, where stuff to upload is
 ${WordFind} $allparams "¤" "+3" $pudPath ;location of .pud file (ini to get Mirrors from)
 ${WordFind} $allparams "¤" "+4" $uploadedSnapshot_Prev_PathOrig ;for checking what was uploaded already
 readinistr $maskExtension $pudPath "Main" "MaskExtension"
 readinistr $onlyUploadChangedFiles $pudPath "Release" "OnlyUploadChangedFiles"
 
 ;Move orig UploadedSnapshot into tmp dir, delete original (avoids issues)
 strcpy $uploadedSnapshot_Prev_Path "$PLUGINSDIR\UploadedPrev.snapshot"
 strcpy $uploadedSnapshot_New_Path "$PLUGINSDIR\UploadedNew.snapshot"
 strcmp $onlyUploadChangedFiles "1" 0 +2
   copyfiles /SILENT /FILESONLY "$uploadedSnapshot_Prev_PathOrig" "$uploadedSnapshot_Prev_Path" ;from orig into temp
 clearerrors
 delete "$uploadedSnapshot_Prev_PathOrig"
 iferrors 0 +3 
  push "Error moving file $uploadedSnapshot_Prev_PathOrig"
  call failQuitMsg 
 
 strcpy $ftp_ListPath "$PLUGINSDIR\ftplist.txt"
 FileOpen $ftp_ListFile $ftp_ListPath w
 strcpy $ftp_intFilesToUpload 0
 
 strcpy $tmp1 -1 ;current mirror Index 
 ftpall_loop:
 call checkForCancelAndQuit
 intop $tmp1 $tmp1 + 1
 readinistr $ftp_url $pudPath "Mirrors" $tmp1
 strcmp $ftp_url "" ftpall_uploadTime ;no mirror left
 ${WordFind} $ftp_url "¤" "#" $ftp_url_TknCount ; =1 if only URL, =2 if URL + FTP_URL
 ${WordFind} $ftp_url "¤" "+1" $tmp5 ; WWW Address
 ${WordFind} $ftp_url "¤" "-1" $ftp_url ;ftp url part
 strcmp $ftp_url_TknCount 1 0 ftpall_loop_goAhead ;this mirror does not have a upload url
   !insertmacro WRITELN " NOT Uploading to: $tmp5 (Not Configured)"
   goto ftpall_loop
 ftpall_loop_goAhead:  ;RUN for every mirror in mirror list
 strcpy $ftp_path $OUT_FOLDER ;what to upload
  ;messagebox MB_OK "$tmp5 -> $ftp_url"
  !insertmacro WRITELN " Uploading to: $tmp5"
  ;nxs::Update /NOUNLOAD /sub "$\rUploading to: $tmp5 ..." /pos $progressBarPos /end
  call enumerateUploadDir
 goto ftpall_loop
 ftpall_uploadTime: ;before this, a list was enumerated; now that list will be processed
 FileClose $ftp_ListFile  
 FileOpen $ftp_ListFile $ftp_ListPath r
  call ftpall_doUpload
 FileClose $ftp_ListFile
 delete $ftp_ListPath 
 copyfiles /SILENT /FILESONLY "$uploadedSnapshot_New_Path" "$uploadedSnapshot_Prev_PathOrig" ;new UploadedSnapshot to where old UploadedSnapshot was
 goto zend 
 
 removeUpdater:
 ${WordFind} $allparams "¤" "+2" $copyTarget
 !insertmacro WRITELN "Removing Updater from: $copyTarget"
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Removing Updater from release folder....$\r$\nPlease wait...` /sub `$\r$\n$\r$\n $copyTarget...` /h 0 /pos $progressBarPos /max 50 /can 0 /end
 !insertmacro REMOVEUPDATER $copyTarget ;also called by all snapshots
 goto zend
 
 nukedir:
 ${WordFind} $allparams "¤" "+2" $copyTarget
 ;Kill target folder
 !insertmacro WRITELN "Emptying folder: $copyTarget"
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Emptying folder....$\r$\nPlease wait...` /sub `$\r$\n$\r$\n $copyTarget...` /h 0 /pos $progressBarPos /max 50 /can 1 /end
 clearerrors
 RMDir /r $copyTarget
 CreateDirectory $copyTarget 
 call checkForCancelAndQuit
 iferrors 0 zend
  ;if any file (with the letter "e" hack) exists, it failed
  IfFileExists "$copyTarget\*e*.*" 0 zend ;only if there are still left over version files in here that couldn't be deleted, could this be a problem
        ;it's be nicer if we could say if any files are still in here though.... 
  push "Can't remove: $copyTarget"
  call failQuitMsg
 goto zend
 
 makeStamp:
 MessageBox MB_OK "makeStamp: No longer exists?"
 ${WordFind} $allparams "¤" "+2" $snapdest ;stamp file we will make
 ${WordFind} $allparams "¤" "+3" $snapFile ;file to make Stamp from
 ;1) Get all info
 ${GetTime} "$snapFile" "M" $0 $1 $2 $3 $4 $5 $6
	; $0="12"       day
	; $1="10"       month
	; $2="2004"     year
	; $3="Tuesday"  day of week name
	; $4="2"        hour
	; $5="32"       minute
	; $6="03"       seconds
 ;2) Make date into stamp
 Push $0 ; day
 Push $1 ; month
 Push $2 ; year
 Call Date2Serial
 Pop $3 ;serial 39324
 ;3) Combine everything into Stamp file
 strcpy $9 "$3.$4.$5.$6"
 ;MessageBox MB_OK "stamp $9"
 FileOpen $8 "$snapdest" w
 FileWrite $8 "$9"
 FileClose $8
 goto zend
 
 snapPatch: ;snapPatch¤FOLDER¤PROJ_FOLDER¤INT_VERSION¤pudPath
  ;this is only called in patch mode my the GUI, when there is only one version
  ;purpose: have a snapshot for reference when releasing future version, to ensure this first version remained unaltered
 ${WordFind} $allparams "¤" "+2" $SEARCHDIR
 ;ReadINIStr $SEARCHDIR $EXEDIR\compile.dat snap dir
 ${WordFind} $allparams "¤" "+3" $PROJ_FOLDER
 ${WordFind} $allparams "¤" "+4" $INT_VERSION_NEW 
 ${WordFind} $allparams "¤" "+5" $pudPath ;for excl list
 ;ReadINIStr $snapdest $EXEDIR\compile.dat snap file
 !insertmacro REMOVEUPDATER $SEARCHDIR ;in case user has Updater stuff in his Release folders already
 ;MessageBox MB_OK "SnapPatch: [$allparams]"
 createdirectory "$PROJ_FOLDER\Snapshots\"
 
 ;make new snap
 delete "$PROJ_FOLDER\Snapshots\tmp$INT_VERSION_NEW.snp"
 strcpy $snapdest "$PROJ_FOLDER\Snapshots\tmp$INT_VERSION_NEW.snp"
 strcpy $7 "(Newest)"
 call Snap ; for patch snap only
 ;MessageBox MB_OK "Snapped $PROJ_FOLDER\Snapshots\tmp$INT_VERSION_NEW.snp"
 
 ;if old snap exists, compare
 call checkIfNewestVersionAltered
 goto zend
 
 snapSync: ;now same params as below ;OLD snap¤FOLDER¤SnapPath¤pudPath¤boolDontRemoveUpdater
 strcpy $snapMode "snapshot"
 !insertmacro WRITELN ">Generating Snapshot for Sync/Recovery Mode..."
 goto snapSync_DoIt
 
 snapSyncComp: 
 strcpy $snapMode "snapshotComp"
 !insertmacro WRITELN ">Generating Snapshot and Compressing for Sync/Recovery Mode..."
 goto snapSync_DoIt
 
 snapSync_DoIt: ;snap¤FOLDER¤SnapPath¤snapCompressToPath¤pudPath
 ${WordFind} $allparams "¤" "+2" $SEARCHDIR
 ;ReadINIStr $SEARCHDIR $EXEDIR\compile.dat snap dir
 ${WordFind} $allparams "¤" "+3" $snapdest
 ${WordFind} $allparams "¤" "+4" $snapCompressToPath
 ${WordFind} $allparams "¤" "+5" $pudPath
 clearerrors
 readinistr $maskExtension $pudPath "Main" "MaskExtension"
 ;ReadINIStr $snapdest $EXEDIR\compile.dat snap file
 ;!insertmacro REMOVEUPDATER $SEARCHDIR ;in case user has Updater stuff in his Release folders already;NO, can't do that here, this is the release dir 
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top "Generating Snapshot and Compressing for Sync/Recovery Mode.$\r$\nPlease wait..." /sub `$\r$\n$\r$\n Preparing...` /h 0 /pos $progressBarPos /max 50 /can 1 /end 
 FileOpen $snapFile $snapdest w
 iferrors 0 snapSync_DoIt_OpenedSnap
  ;push "Can't open $snapdest"
  ;call failQuitMsg
  !insertmacro WRITELN "Can't open $snapdest [Error ${__LINE__}]"
  !insertmacro WRITELN "Retrying in 10 sec..."
  ;messagebox mb_ok "Ready to retry?"
  sleep 10000 
  goto snapSync_DoIt

 snapSync_DoIt_OpenedSnap:
  
 ;Prepare comp tools
 SetOutPath "$PLUGINSDIR\"
   File "_plugin\CompressFile_.exe"
   File "_plugin\lzma_.exe" ;real lzma
   copyfiles /SILENT /FILESONLY "$EXEDIR\$EXEFILE" "$PLUGINSDIR\LZMA.exe"
   copyfiles /SILENT /FILESONLY "$EXEDIR\$EXEFILE" "$PLUGINSDIR\CompressFile.exe"
   ;File /oname=LZMA.exe "_plugin\EXEProxy.exe"  ;proxy
   ;File /oname=CompressFile.exe "_plugin\EXEProxy.exe"  ;proxy
 ;
 ;strcpy $snapMode "snapshotComp"
 ;MessageBox MB_OK "$SEARCHDIR $snapdest $snapCompressToPath -"
 call findfile0
 FileClose $snapFile
 clearerrors
 
 ;Compress snapshot file: SnapDest
 copyfiles /SILENT /FILESONLY "$snapdest" "$PLUGINSDIR\orig.tmp"
 iferrors 0 +3
    push "Can't compress file: $snapdest"
    call failQuitMsg
 execwait '$PLUGINSDIR\CompressFile.exe tmp.tmp orig.tmp'
   clearerrors
 copyfiles /SILENT /FILESONLY "$PLUGINSDIR\tmp.tmp" "$snapdest"
   iferrors 0 +3
    push "Can't overwrite file: $snapdest"
    call failQuitMsg
 
 goto zend
 
 newproject:
 ReadINIStr $copySource $EXEDIR\compile.dat newproj dir
 createdirectory "$copySource\Snapshots"
 createdirectory "$copySource\Archive"
 FileOpen $0 "$copySource\Archive\do_not_modify" w
 FileClose $0
 ;createdirectory "$copySource\_WWW"
 ;createdirectory "$copySource\_Release"
 iferrors 0 +3
  push "Can't create $copySource [Error ${__LINE__}]"
  call failQuitMsg
  
 ;GUID
 ReadINIStr $1 $EXEDIR\compile.dat newproj projINI
 call CreateGUID
 pop $0
 strcpy $0 $0 -1 1
 WriteINIStr $1 "Main" "GID" "$0" ;write GUID into project ini 
  
 goto zend
 
 copyfolder:
  ${WordFind} $allparams "¤" "+2" $copySource
  ${WordFind} $allparams "¤" "+3" $copyTarget
  clearerrors
  !insertmacro WRITELN "Copying files to: $copyTarget"
  CreateDirectory $copyTarget
  iferrors 0 +3
    push "Can't create $copyTarget [Error ${__LINE__}]"
    call failQuitMsg
    
  CopyFiles "$copySource\*" $copyTarget 
  iferrors 0 +3
    push "Unable to copy files to: $copyTarget [Error ${__LINE__}]"
    call failQuitMsg   
 
 goto zend
 
 release:
 ;!insertmacro WRITELN "Updates are being compiled."
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Updates are being compiled.$\r$\nPlease wait...` /sub `$\r$\n$\r$\n Preparing...` /h 0 /pos $progressBarPos /max 50 /can 0 /end

 ;Read INI
 ReadINIStr $copySource $EXEDIR\compile.dat copy source
 ReadINIStr $copyTarget $EXEDIR\compile.dat copy target
 
 !insertmacro WRITELN "Emptying folder: $copyTarget"
 ;nxs::Update /NOUNLOAD /sub "$\r$\n$\r$\n Emptying folder..." /pos $progressBarPos /end
 
 clearerrors
 ;Kill target folder
 RMDir /r "$copyTarget"
 iferrors 0 release_part2
  ;if any file (with the letter "e" hack) exists, it failed
  IfFileExists "$copyTarget\*e*.*" 0 release_part2 ;only if there are still left over version files in here that couldn't be deleted, could this be a problem
        ;it's be nicer if we could say if any files are still in here though.... 
  push "Can't remove: $copyTarget"
  call failQuitMsg
 release_part2:
 !insertmacro WRITELN "Copying newest version to folder: $copyTarget"
 ;nxs::Update /NOUNLOAD /sub "$\r$\n Copying newest version to folder: $copyTarget" /pos $progressBarPos /end
 
 ;check for cancel
 ;nxs::HasUserAborted /NOUNLOAD
 Pop $0
 StrCmp $0 1 zend ;cancelled
 
 release_preCreateFolder:
 clearerrors
 CreateDirectory $copyTarget
 iferrors 0 release_FolderCreated
  ;push "Can't create $copyTarget [Error ${__LINE__}]"
  ;call failQuitMsg
  !insertmacro WRITELN "Can't create $copyTarget [Error ${__LINE__}]"
  !insertmacro WRITELN "Retrying in 10 sec..."
  ;messagebox mb_ok "Ready to retry?"
  sleep 10000 
  goto release_preCreateFolder
  
 release_FolderCreated:
 
 iffileexists "$copySource\*.*" 0 nocopysource ;if sourceDir doesn't exist, error
 !insertmacro WRITELN "Copying files to: $copyTarget"
 CopyFiles "$copySource\*" $copyTarget
 ;nxs::Update /NOUNLOAD /sub "$\r$\n$\r$\n 100% Complete" /pos $progressBarPos /end
 iferrors 0 +3
  push "Unable to copy files to: $copyTarget [Error ${__LINE__}]"
  call failQuitMsg 

 sleep 400
 goto zend
 
 nocmdln:
 ;ExecShell "open" '"notepad.exe"' '' SW_HIDE   
  
 MessageBox MB_OK "${PRODUCT_NAME} by Puchisoft, Inc. $\nVisit http://www.puchisoft.com"
 goto zend  
 
 nocopysource: 
  push "The latest version's folder seems to be empty!$\nFolder: $copySource"
  call failQuitMsg
 
 zend: ;Success! 
 call checkForCancelAndQuit
 call succeedCleanupAndQuit
 ;quit
 
 
 zpatch:

 SetOutPath $PLUGINSDIR
 File "GenPat.exe"
 ;copyfiles "${NSISDIR}\Bin\GenPat.exe" "$PLUGINSDIR\" ;Doesn't seem to work
 
 ;read main vars
 ${WordFind} $allparams "¤" "+2" $pudPath ; all variables could now be read in via cmdline, except for maybe MMF2's string limit?
 readinistr $maskExtension $pudPath "Main" "MaskExtension"
 
 ReadINIStr $PRODUCT_NAME $EXEDIR\compile.dat patch PRODUCT_NAME
 ReadINIStr $PROJ_FOLDER   $EXEDIR\compile.dat patch PROJ_FOLDER
 ReadINIStr $OUT_FOLDER   $EXEDIR\compile.dat patch OUT_FOLDER       ; ...\_WWW\patch
 
 ReadINIStr $INT_VERSION_NEW   $EXEDIR\compile.dat patch INT_VERSION_NEW
 ReadINIStr $VERSION_NEW   $EXEDIR\compile.dat patch VERSION_NEW
 ReadINIStr $FOLDER_NEW   $EXEDIR\compile.dat patch FOLDER_NEW
 ReadINIStr $STATUS_NEW   $EXEDIR\compile.dat patch STATUS_NEW
 
 !insertmacro WRITELN "Generating Patches for $PRODUCT_NAME ..."
 ;nxs::Show /NOUNLOAD `${PRODUCT_NAME}` /top `Generating Patches for $PRODUCT_NAME ...$\r$\nPlease wait...` /sub `$\r$\n$\r$\n Preparing...` /h 0 /pos $progressBarPos /max 50 /can 1 /end

 iffileexists "$FOLDER_NEW\*.*" 0 noupdatetarget ;if Dir doesn't exist, error
 
#!if ${PRODUCT_EDITION} == "Free"
#intcmp $INT_VERSION_NEW 10 +3 +3 0   
# push "The trial of Patch Mode for this project has expired.$\r$\nPlease change to Sync Mode to continue using the Freeware Edition.$\r$\nTo use Patch Mode, a Non-Freeware Edition must be purchased. You can continue evaluating Patch Mode by starting a new project."
# call failQuitMsg
# !insertmacro WRITELN "Warning: Patch Mode is only included as a demonstration! You may not release an Updater in Patch Mode, unless you purchase a Non-Freeware Edition."
#!endif

 ;RMDir /r $OUT_FOLDER
 createdirectory $OUT_FOLDER
 iferrors 0 +3
  push "Can't create folder: $OUT_FOLDER [Error ${__LINE__}]"
  call failQuitMsg
 
 createdirectory "$PROJ_FOLDER\Snapshots\" ;you never know...
 createdirectory "$PROJ_FOLDER\Patches\"
 
 strcpy $patchMapFullPath "$PROJ_FOLDER\Patches\patchmap_full.ini"
 strcpy $patchMapTrimPath "$OUT_FOLDER\patchmap$maskExtension"
 delete $patchMapTrimPath
 iferrors 0 +3
  push "Can't delete files in: $OUT_FOLDER"
  call failQuitMsg
 
 ;Kill all tmp snapshots  
 delete "$PROJ_FOLDER\Snapshots\tmp*.snp"
 iferrors 0 +3
  push "Can't delete files in: $PROJ_FOLDER"
  call failQuitMsg
 
 ;Make a snapshot for FOLDER_NEW
 strcpy $tmp0 ".snp"
 strcpy $tmp0 tmp$INT_VERSION_NEW$tmp0
 strcpy $SNAP_NEW "$PROJ_FOLDER\Snapshots\$tmp0"
 ;iffileexists "$SNAP_NEW" +5 0 ;;!!!+5  
  strcpy $SEARCHDIR $FOLDER_NEW
  strcpy $snapdest $SNAP_NEW
  strcpy $7 $VERSION_NEW ;execwait '"$EXEDIR\compiler.exe" snap¤$FOLDER_NEW¤$SNAP_NEW¤$VERSION_NEW¤' ;gen it if it does not
  Call Snap ;generate a snapshot to compare
  
  call checkIfNewestVersionAltered ;checks if newest version has an old snap, fails if diff, makes old snap if doesn't exist
  clearerrors
  ;FileOpen $cLogFile "$EXEDIR\compiler.log" a
  ;FileSeek $cLogFile 0 END
  
 readinistr $patchRecoverModeAllowed $pudPath "Main" "RecoverMode" 
  
 writeinistr $patchMapTrimPath "Names" "$INT_VERSION_NEW" "$VERSION_NEW" ;take note of newest version name

 StrCpy $tmp1 -1
patchLoop: ;loop through all OLD folders, making patches to update each to the New
 call checkForCancelAndQuit
 IntOp $tmp1 $tmp1 + 1 ;start at 0

 ReadINIStr $FOLDER_OLD   $EXEDIR\compile.dat  $tmp1 FOLDER_OLD
  StrCmp    $FOLDER_OLD "" zend2 ;done   
 ReadINIStr $INT_VERSION   $EXEDIR\compile.dat $tmp1 INT_VERSION
 ReadINIStr $VERSION   $EXEDIR\compile.dat     $tmp1 VERSION
 ReadINIStr $STATUS_OLD   $EXEDIR\compile.dat  $tmp1 STATUS_OLD
 
 writeinistr $patchMapTrimPath "Names" "$INT_VERSION" "$VERSION" ;do this for all old versions, no matter how they are updated from
  
 StrCmp    $STATUS_OLD "2" 0 pNotSyncStatus ;Sync - no patch, leave excluded from trimmed patch map
  strcmp $patchRecoverModeAllowed "1" patchLoop ;must be allowed for sync to work
   push "ERROR: Version $INT_VERSION ($VERSION) has a Status of Retired (Sync), which requires Allowing File Recovery. Please enable this feature."
   call failQuitMsg
  
  goto patchLoop
 pNotSyncStatus:
 StrCmp    $STATUS_OLD "1" 0 pActiveStatus ;Retired(Patch) 
  ;make note of this in trimmed patch map $patchMapTrimPath, copy over archive of patch into out_folder
  clearerrors
  readinistr $INT_VERSION_INTERMEDIATE $patchMapFullPath "Map" $INT_VERSION  
  copyfiles /SILENT /FILESONLY "$PROJ_FOLDER\Patches\patch$INT_VERSION_$INT_VERSION_INTERMEDIATE$maskExtension" "$OUT_FOLDER\" ;release this needed intermediate .patch
  iferrors 0 +3
   push "Could not copy archival copy of patch ($INT_VERSION-$INT_VERSION_INTERMEDIATE) to $OUT_FOLDER for version $VERSION. If you deleted this patch, please change this version's Status to Retired (Sync) or Active."
   call failQuitMsg
  
  writeinistr $patchMapTrimPath "Map" "$INT_VERSION" "$INT_VERSION_INTERMEDIATE" ;just copy what full patch map knows into trim  
  goto patchLoop
 pActiveStatus: 
 
 strcpy $PATCH_NAME "patch$INT_VERSION_$INT_VERSION_NEW" ;.patch name
 iffileexists "$PROJ_FOLDER\Patches\$PATCH_NAME$maskExtension" 0 +3 ;.patch
  !insertmacro WRITELN "Using existing Archive copy of Patch ($VERSION-$VERSION_NEW)."
  goto patchExistsInArchive

 ;prepare to make patch
 iffileexists "$FOLDER_OLD\*.*" 0 noupdatesource ;if Dir doesn't exist, error

 ;Make a snapshot for current FOLDER_OLD
 strcpy $tmp0 ".snp"
 strcpy $tmp0 tmp$INT_VERSION$tmp0
 strcpy $SNAP_CUR "$PROJ_FOLDER\Snapshots\$tmp0"
 ;iffileexists "$SNAP_CUR" +5 0 ;!!!+5
  strcpy $SEARCHDIR $FOLDER_OLD
  strcpy $snapdest $SNAP_CUR
  strcpy $7 $VERSION ;execwait '"$EXEDIR\compiler.exe" snap¤$FOLDER_NEW¤$SNAP_NEW¤$VERSION_NEW¤' ;gen it if it does not
  Call Snap ;generate a snapshot to compare
  
  call checkIfOldVersionAltered ;checks if version has an old snap, fails if diff, makes old snap if doesn't exist
  strcmp $R0 "SyncIt" patchLoop
  clearerrors
  ;MessageBox MB_OK "Gen'd Snap: snap¤$FOLDER_OLD¤$SNAP_CUR¤"
 
 ;Create actual Patch! 
 !insertmacro WRITELN ">Creating patch ($VERSION-$VERSION_NEW) ..."
 ;nxs::Update /NOUNLOAD /top `Generating Patches for $PRODUCT_NAME ...$\r$\nPlease wait...` /sub "$\r$\n$\r Creating patch ($VERSION-$VERSION_NEW) ..." /pos $progressBarPos /end
 clearerrors
 rmdir "$PLUGINSDIR\$PATCH_NAME\"
 createdirectory "$PLUGINSDIR\$PATCH_NAME\"
 iferrors 0 +3
  push "Can't empty folder: $PLUGINSDIR\$PATCH_NAME\"
  call failQuitMsg
 FileOpen $tmp3 "$SNAP_CUR" r
 FileOpen $tmp4 "$SNAP_NEW" r
  ;Loop through all newSnap Dirs with $tmp2 as curLine of snapshop
  FileRead $tmp4 $tmp2 ;Skip first two lines, they are [dirs], ¤=0
  FileRead $tmp4 $tmp2
  StrCpy $tmp5 0 ;Index of patch output file NDir
  patch_Loop_Dirs_N2O: ;comp new to old
   ;ReadLn
   FileRead $tmp4 $tmp2
   strcpy $tmp2 $tmp2 -2 ;kill newLine
   StrCmp $tmp2 "[files]" patch_Loop_Dirs_O2N_begin ;this means that it's time to move on
   ${WordFind} $tmp2 "=" "+1" $tmp2 ;trim current line to just the ini Item

   ;Load Cur pair of dirs
   ReadINIStr $tmp8   "$SNAP_CUR"  "dirs" $tmp2 ;$tmp3 is current snap file
   ;ReadINIStr $tmp9   "$SNAP_NEW"  "dirs" $tmp2 ;$tmp4 is New     snap file
   ;Compare cur pair
   StrCmp $tmp8 "1" patch_Loop_Dirs_N2O
    !insertmacro WRITELN " New Folder: $tmp2"
    WriteINIStr "$PLUGINSDIR\$PATCH_NAME\mod.i" "NDir" $tmp5 "$tmp2"
    ;nxs::Update /NOUNLOAD /sub "$\r$\n$\r Generating patch ($VERSION-$VERSION_NEW) ... Adding New Directory Information..." /pos $progressBarPos /end
    IntOp $tmp5 $tmp5 + 1
   goto patch_Loop_Dirs_N2O
  ;EndOfLoop: PL_dirsN2O
  
  patch_Loop_Dirs_O2N_begin:
  call checkForCancelAndQuit
  ;Loop through all cur Dirs with $tmp2 as curLine of snapshop
  FileRead $tmp3 $tmp2 ;Skip first two lines, they are [dirs], ¤=0
  FileRead $tmp3 $tmp2
  StrCpy $tmp5 0 ;Index of patch output file MDir
  patch_Loop_Dirs_O2N: ;cmp new to old
   ;ReadLn
   FileRead $tmp3 $tmp2
   strcpy $tmp2 $tmp2 -2 ;kill newLine
   StrCmp $tmp2 "[files]" patch_Loop_Files_N2O_begin ;this means that it's time to loop files
   ${WordFind} $tmp2 "=" "+1" $tmp2 ;trim current line to just the ini Item ;folder path
   
   ;check if should exclude   
   call isPathExcluded ;"$tmp2" as path
    Pop $9
    strcmp $9 "Exclude" patch_Loop_Dirs_O2N
     

   ;Load Cur pair of dirs
   ;ReadINIStr $tmp8   "$SNAP_CUR"  "dirs" $tmp2 ;$tmp3 is current snap file
   ReadINIStr $tmp9   "$SNAP_NEW"  "dirs" $tmp2 ;$tmp4 is New     snap file
   ;Compare cur pair

   ;messagebox MB_OK "$tmp2 -> $tmp8 , $tmp9"

   StrCmp $tmp9 "1" patch_Loop_Dirs_O2N
    !insertmacro WRITELN " Remove Folder: $tmp2"
    WriteINIStr "$PLUGINSDIR\$PATCH_NAME\mod.i" "DDir" $tmp5 "$tmp2"
    ;nxs::Update /NOUNLOAD /sub "$\r$\n$\r Generating patch ($VERSION-$VERSION_NEW) ... Adding Delete Directory Information..." /pos $progressBarPos /end
    IntOp $tmp5 $tmp5 + 1
   goto patch_Loop_Dirs_O2N
  ;EndOfLoop: PL_dirsO2N

  patch_Loop_Files_N2O_begin:
  call checkForCancelAndQuit
  FileRead $tmp4 $tmp2 ;Skip first line, its ¤=0
  strcpy $tmp5 0 ;New Files
  strcpy $tmp6 0 ;Modified Files
  clearerrors
  patch_Loop_Files_N2O:
   call checkForCancelAndQuit
   FileRead $tmp4 $tmp2
   StrCmp $tmp2 "" patch_Loop_Files_O2N_begin ;EOF, this means that it's time to loop filesO2N
   strcpy $tmp2 $tmp2 -2 ;kill newLine
   ${WordFind} $tmp2 "=" "+1" $tmp2 ;trim current line to just the ini Item

   ;Load Cur pair of dirs
   ReadINIStr $tmp8   "$SNAP_CUR"  "files" $tmp2 ;$tmp3 is current snap file
   ReadINIStr $tmp9   "$SNAP_NEW"  "files" $tmp2 ;$tmp4 is New     snap file
   
   ;messagebox MB_OK "$tmp2 -> $tmp8 , $tmp9"
   ;Compare cur pair
   StrCmp $tmp8 $tmp9 patch_Loop_Files_N2O ;exist+equal=noChange
   StrCmp $tmp8 "" 0 patch_Loop_Files_N2O_FileModified ;This files is NEW ;!! When adding the file, check if it exists ;)
    !insertmacro WRITELN " New File: $tmp2"
    WriteINIStr "$PLUGINSDIR\$PATCH_NAME\mod.i" "NFiles" $tmp5 "$tmp2"
    ;nxs::Update /NOUNLOAD /sub "$\r Generating patch ($VERSION-$VERSION_NEW) ... Adding file $tmp2" /pos $progressBarPos /end
     clearerrors
     copyfiles /SILENT /FILESONLY "$FOLDER_NEW\$tmp2" "$PLUGINSDIR\$PATCH_NAME\$tmp5.n"
     iferrors 0 +2
      messagebox MB_OK|MB_ICONEXCLAMATION "Could not include file in patch: $FOLDER_NEW$tmp2"
    IntOp $tmp5 $tmp5 + 1
    goto patch_Loop_Files_N2O
    
    patch_Loop_Files_N2O_FileModified:
   ;File Modified
    ;check if should exclude    
    call isPathExcluded ;"$tmp2" as path
     Pop $9
     strcmp $9 "Exclude" patch_Loop_Files_N2O
   
    !insertmacro WRITELN " Patched File: $tmp2"
    WriteINIStr "$PLUGINSDIR\$PATCH_NAME\mod.i" "MFiles" $tmp6 "$tmp2"
     ;nxs::Update /NOUNLOAD /sub "$\r Generating patch ($VERSION-$VERSION_NEW) ... Getting patch data for file $tmp2" /pos $progressBarPos /end
     nsExec::ExecToLog '"$PLUGINSDIR\GenPat.exe" "$FOLDER_OLD$tmp2" "$FOLDER_NEW$tmp2" "$PLUGINSDIR\$PATCH_NAME\$tmp6.m"'
     pop $tmp0
     strcmp $tmp0 "0" +2
      messagebox MB_OK "Error $tmp0 when generating patch of file: $FOLDER_NEW$tmp2"
    IntOp $tmp6 $tmp6 + 1
   goto patch_Loop_Files_N2O
  ;EndOfLoop: PL_filesN2O
 
  patch_Loop_Files_O2N_begin:
  call checkForCancelAndQuit
  FileRead $tmp3 $tmp2 ;Skip first line, its ¤=0
  strcpy $tmp5 0 ;Del Files
  clearerrors
  patch_Loop_Files_O2N:
   FileRead $tmp3 $tmp2
   StrCmp $tmp2 "" patch_Loop_End ;EOF, this means that it's time to loop filesO2N
   strcpy $tmp2 $tmp2 -2 ;kill newLine
   ${WordFind} $tmp2 "=" "+1" $tmp2 ;trim current line to just the ini Item

   ;check if should exclude    
    call isPathExcluded ;"$tmp2" as path
     Pop $9
     strcmp $9 "Exclude" patch_Loop_Files_O2N

   ;Load Cur pair of dirs
   ;ReadINIStr $tmp8   "$SNAP_CUR"  "files" $tmp2 ;$tmp3 is current snap file
   ReadINIStr $tmp9   "$SNAP_NEW"  "files" $tmp2 ;$tmp4 is New     snap file

   ;messagebox MB_OK "$tmp2 -> $tmp8 , $tmp9"
   ;Compare cur pair
   StrCmp $tmp9 "" 0 patch_Loop_Files_O2N ;This file must be Deleted
    ;nxs::Update /NOUNLOAD /sub "$\r$\n$\r Generating patch ($VERSION-$VERSION_NEW) ... Writing delete data for file $tmp2" /pos $progressBarPos /end
    !insertmacro WRITELN " Deleted File: $tmp2"
    WriteINIStr "$PLUGINSDIR\$PATCH_NAME\mod.i" "DFiles" $tmp5 "$tmp2"
    IntOp $tmp5 $tmp5 + 1
    goto patch_Loop_Files_O2N
  ;EndOfLoop: PL_filesN2O
  
  patch_Loop_End:
   FileClose $tmp3
   FileClose $tmp4
   strcpy $tmp3 ""
   strcpy $tmp4 ""
   
   ;Now that we have a folder full of these update files, put them all into one file
   SetOutPath "$PLUGINSDIR\$PATCH_NAME"
   File "_plugin\CompressFile_.exe"
   File "_plugin\lzma_.exe" ;real lzma
   copyfiles /SILENT /FILESONLY "$EXEDIR\$EXEFILE" "$PLUGINSDIR\$PATCH_NAME\LZMA.exe"
   copyfiles /SILENT /FILESONLY "$EXEDIR\$EXEFILE" "$PLUGINSDIR\$PATCH_NAME\CompressFile.exe"   
   ;File /oname=CompressFile.exe "_plugin\EXEProxy.exe" ;proxy
   ;File /oname=LZMA.exe "_plugin\EXEProxy.exe" ;proxy

   
   WriteINIStr "$PLUGINSDIR\$PATCH_NAME\n.n" "1" "1" "1" ;make two dummy files to make sure the wildcards used with CompressFile dont fail...stupid
   WriteINIStr "$PLUGINSDIR\$PATCH_NAME\m.m" "1" "1" "1"
   WriteINIStr "$PLUGINSDIR\$PATCH_NAME\mod.i" "1" "1" "1" ;in case the patch does absolutely nothing at all, this file must still exist
   !insertmacro WRITELN "Finalizing patch ($VERSION-$VERSION_NEW) ..."
   ;nxs::Update /NOUNLOAD /sub "$\r$\n Finalizing patch ($VERSION-$VERSION_NEW) ... Compressing with LZMA..." /pos $progressBarPos /end
   ;nsExec::ExecToLog '$PLUGINSDIR\$PATCH_NAME\CompressFile.exe tmp.tmp mod.i *.n *.m'
   execwait '$PLUGINSDIR\$PATCH_NAME\CompressFile.exe tmp.tmp mod.i *.n *.m'
 patchCopyAround:  
   clearerrors  
   copyfiles /SILENT /FILESONLY "$PLUGINSDIR\$PATCH_NAME\tmp.tmp" "$PROJ_FOLDER\Patches\$PATCH_NAME$maskExtension" ;keep archive copy .patch
 patchExistsInArchive: 
   copyfiles /SILENT /FILESONLY "$PROJ_FOLDER\Patches\$PATCH_NAME$maskExtension" "$OUT_FOLDER\$PATCH_NAME$maskExtension" ;release .patch to Updates Folder
   iferrors 0 +3    
    !insertmacro WRITELN " Can't copy patch [src:$PLUGINSDIR\$PATCH_NAME\] to: $OUT_FOLDER\ and/or $PROJ_FOLDER\Patches\ ... Retry? NOTE: To answer this question, look for a message box behind this window! Sorry."
    MessageBox MB_YESNO " Can't copy patch to: $OUT_FOLDER\ and/or $PROJ_FOLDER\Patches\ ... Retry?" IDYES patchCopyAround      
   iferrors 0 +3
    push "Can't copy patch to: $OUT_FOLDER\ and/or $PROJ_FOLDER\Patches\"
    call failQuitMsg
   
   ;Successfully made a patch
   
   ;Delete previous archival copy of old patch from this old ver to another (now) old version
   readinistr $INT_VERSION_INTERMEDIATE $patchMapFullPath "Map" $INT_VERSION
   strcmp $INT_VERSION_INTERMEDIATE $INT_VERSION_NEW +2 ;don't delete the new patch
    delete "$PROJ_FOLDER\Patches\patch$INT_VERSION_$INT_VERSION_INTERMEDIATE$maskExtension" ;.patch
   
   ;make note in full patch map
   clearerrors
   writeinistr $patchMapFullPath "Map" "$INT_VERSION" "$INT_VERSION_NEW"
   writeinistr $patchMapTrimPath "Map" "$INT_VERSION" "$INT_VERSION_NEW"   
   iferrors 0 +3
    push "Can't write patch maps at: $patchMapFullPath and $patchMapTrimPath"
    call failQuitMsg
      
 
 goto patchLoop
 
 
 noupdatesource: 
 push "Could not make patch due to missing folder: $FOLDER_OLD"
 call failQuitMsg

 noupdatetarget:
 push "Could not make patch due to missing folder: $FOLDER_NEW"
 call failQuitMsg 
 
 zend2:
 call checkForCancelAndQuit
 delete "$exedir\compile.dat" ; important to delete after patch, causes probs next time o.w. 
 delete "$PROJ_FOLDER\Snapshots\tmp*.snp" ;Kill all tmp snapshots, cleanup purposes only  
 RMDir /r /REBOOTOK "$PLUGINSDIR" ;\patchFiles

 call succeedCleanupAndQuit
 
 ;allowreview:
 ;execshell open $PLUGINSDIR
 quit
FunctionEnd

Section
SectionEnd

Function .onGUIEnd
 ;Delete "$EXEDIR\compile.dat"
FunctionEnd

;;;;;;;;;;;;;;;; Snapshot gen stuff
Function findfile0
  Delete "$snapdest"
  strcmp $snapMode "snp" 0 +3
  WriteINIStr "$snapdest" dirs "¤" "0"
  WriteINIStr "$snapdest" files "¤" "0"
  StrCpy $R7 "1"
  StrCpy $R8 "0"
  StrCpy $R9 "0"
 ; StrCpy $SEARCHDIR $EXEDIR ; <-- modify directory (from input or fixed)
  Push "" ;cur relative path
  Call findfile2
  Call findfile1
FunctionEnd


Function findfile1
findfile1_loop:
  ;ReadINIStr $3 "$snapdest" dirs $R7
  pop $3
  StrCmp $3 "" findfile1_done
    Push $3
    Call findfile2
    IntOp $R7 $R7 + 1
    IntCmp $R7 $R8 0 0 findfile1_done
  Goto findfile1_loop
findfile1_done:
FunctionEnd


Function findfile2
Pop $2
FindFirst $0 $1 "$SEARCHDIR\$2\*.*"
findfile2_loop:
  StrCmp $1 "" findfile2_done
  StrCmp $1 "." findfile2_loop02
  StrCmp $1 ".." findfile2_loop02
  ;detailprint "$2\$1"
  ;!insertmacro WRITELN " Current File: $2\$1" --too much bs, don't care
  ;nxs::Update /NOUNLOAD /sub "$\r$\nCurrent File: $2\$1" /pos $progressBarPos /end
  !insertmacro WRITELN " Current File: $2\$1"
  IfFileExists "$SEARCHDIR\$2\$1\*.*" 0 findfile2_loop01
    Call subdir
    Goto findfile2_loop02
  findfile2_loop01:
  Call filewrite
  findfile2_loop02:
  FindNext $0 $1
  Goto findfile2_loop
findfile2_done:
FunctionEnd


Function subdir
  IntOp $R8 $R8 + 1
  strcmp $snapMode "snp" sDoInclude ;In Patch, incl folder, not in sync
  goto subdir_done 

 sDoInclude:
;  strcmp $snapMode "snp" 0 subdir_done ;patch mode only
  WriteINIStr "$snapdest" dirs "$2\$1" "1" ;include the fact that this dir exists in snp
 subdir_done:
  ;call checkForCancelAndQuit
      call increaseAndLoopProgressBar
  push "$2\$1" ;
FunctionEnd

Function isPathExcluded ;called by filewrite and zpatch 
 ;params: $tmp2 as path, $pudPath for .dispatch file
 strcpy $excl_itt "0"
 excl_loop: 
 readinistr $excl_curStr $pudPath "UpdateExcludes" $excl_itt ;read in current string
  strcmp $excl_curStr "" doInclude ;current file survived all filters  
  intop $excl_itt $excl_itt + 1 ;for next time
  ;check if current banned file path is found in current
  ${WordFind} "$tmp2" "$excl_curStr" "*" $snapTmp ; outputs # of times string was found
  strcmp $snapTmp "$tmp2" excl_loop ;if not found in cur filter
   !insertmacro WRITELN " -Excluding: $tmp2"
   Push "Exclude"   
   goto eoFunc
 doInclude:
  Push "Include"
 eoFunc:
FunctionEnd

Function filewrite
  IntOp $R9 $R9 + 1  
 ;make sure cur file path should not be excluded 
 
 strcpy $tmp2 "$2\$1" ;used by both static Updater files real exclude, and dynamic user excludes in function
 
 ;compare absolute relative path to make sure Updater.exe isn't excluded from non-root (like Dispatcher's \Data\Updater.exe)
 strcmp "$tmp2" "\Updater.exe"  endOfFileWrite ;if not found, move on
 strcmp "$tmp2" "\Updater.dat"  endOfFileWrite ;if not found, move on
 strcmp "$tmp2" "\Updater.bmp"  endOfFileWrite ;if not found, move on
 strcmp "$tmp2" "\UpdaterLicense.txt"  endOfFileWrite ;if not found, move on   
 
 strcmp $snapMode "snp" doInclude ;In Patch, nothing but the Updater is excluded from snapshots, only at patch make time
 
 call isPathExcluded ;"$tmp2" as path
 Pop $9
 strcmp $9 "Exclude" 0 +3
  strcpy $9 "x¤" ;add an x token to let Updater know to only download if non-existant
   goto doInclude
  strcpy $9 "" ;no x
	
 doInclude:
;  MessageBox MB_OK "FileWrite $SEARCHDIR$2\$1"
  strcmp $snapMode "snp" getMD5 ;for patch mode snaps
  strcmp $snapMode "snapshotComp" 0 withOutCompression
    ;;withCompression:    
  ;This is for each file $SEARCHDIR$2\$1
  ;Take it, copy it to the PlugDir with it's own name.
;  MessageBox MB_OK "SyncComp From $SEARCHDIR$2\$1 to $PLUGINSDIR\$1"
  clearerrors
  copyfiles /SILENT /FILESONLY "$SEARCHDIR$2\$1" "$PLUGINSDIR\$1"
  ;Compress it to it's own name .lzma (now: $maskExtension)
;  MessageBox MB_OK "Compress CompressFile.exe $1.lzma $1"
  ;nsExec::ExecToLog '$PLUGINSDIR\CompressFile.exe $1.lzma $1'
  execwait '$PLUGINSDIR\CompressFile.exe new.lzma "$1"' ;Must use quotes if there is a chance the name could have a space in it; result may not have spaces here, so rename it to proper below
  delete "$1.lzma" ;this makes sure that the same file name can be used in multiple sub-dirs (otherwise rename below would fail is something exists :P)
  rename "new.lzma" "$1.lzma"
  clearerrors
  ;copy it to the destination $snapCompressToPath
;  MessageBox MB_OK "Copy from $PLUGINSDIR\$1.lzma to $snapCompressToPath$2\$1.lzma"
  CreateDirectory "$snapCompressToPath$2\" ;make sure path is made (doesnt auto-happen on XP!)
  copyfiles /SILENT /FILESONLY "$PLUGINSDIR\$1.lzma" "$snapCompressToPath$2\$1$maskExtension" ;copy compressed file, renaming with mask's ext
  iferrors 0 +3
    push "Can't copy file to: $snapCompressToPath$2\$1$maskExtension"
    call failQuitMsg
  goto getMD5
  
 withOutCompression:
  CreateDirectory "$snapCompressToPath$2\" ;make sure path is made (doesnt auto-happen on XP!)
  clearerrors
  copyfiles /SILENT /FILESONLY "$SEARCHDIR$2\$1" "$snapCompressToPath$2\$1$maskExtension";$maskExtension ;copy compressed file, renaming with mask's ext
  iferrors 0 +3
    push "Can't copy file to: $snapCompressToPath$2\$1$maskExtension"
    call failQuitMsg
  goto getMD5
  
 getMD5:
  md5dll::GetMD5File "$SEARCHDIR$2\$1"
  ;gotTheMD5:
  Pop $4
  strcmp $snapMode "snp" 0 +3
   WriteINIStr "$snapdest" files "$2\$1" $4
   goto endOfFileWrite
  strcpy $5 $2 "" 1
;  strcpy $6 $2 1 0 ;first char
;  strcmp $6 "\" 0 +2 ;if it still starts with \, get rid of it again --- DOES NOT WORK.... :(
;   strcpy $5 $2 "" 1
  FileWrite $snapFile "$5\$1¤$4¤$9$\r$\n"
 endOfFileWrite:
  ;call checkForCancelAndQuit
     call increaseAndLoopProgressBar
FunctionEnd

Function enumerateUploadDir 
 ;Adds all files to be uploaded of "UploadDir to current FTP auto-upload mirror" to ftp list ; not uploaded instantly to avoid crash due to Retry dialog+recursion(?)
  strcpy $ftp_pathOrig "$ftp_path"
; put is dir in the user's ftp home, use //put for root-relative ftp_path
  ;StrCpy $ftp_url ftp://rel:pwd@localhost/put
  fileopen $uploadedSnapshot_New $uploadedSnapshot_New_Path w ;write the current Uploaded Snapshot from scratch (must be outside of enumDirTo func, because that function recursively calls itself)
  Call enumerateDirToFTPList
  fileclose $uploadedSnapshot_New
  ;call checkForCancelAndQuit
  
  ;upload these last, make sure no update is triggered until all the data is on the server
  ;ifFileExists "$ftp_pathOrig\Updater.snapshot" 0 addCurVer ;Wait, why would we want this uploaded last? If a bad update is triggered, might as well have Updater keep the new files (via crc) rather than insuring the old files are kept; if any files are different than expected, this will fail either way
  
 ;addCurVer:
  ;nxs::Update /NOUNLOAD /sub "$\rScanning files for mirror: $tmp5 ...$\rFile: ver$maskExtension" /pos $progressBarPos /end  
  FileWrite $ftp_ListFile "$ftp_url/ver$maskExtension$\r$\n"
  FileWrite $ftp_ListFile "$ftp_pathOrig\ver$maskExtension$\r$\n"    
  IntOp $ftp_intFilesToUpload $ftp_intFilesToUpload + 1
;  done:
FunctionEnd

Function enumerateDirToFTPList ;called only from enumerateUploadDir above

  Push $0 ; search handle
  Push $1 ; file name
  Push $2 ; attributes
  Push $3 ; curFile MD5
  Push $4 ; cur line in Prev Uploaded Snapshot file

  FindFirst $0 $1 "$ftp_path\*" ;scans through files
  
  ;!insertmacro WRITELN "Scanning files for mirror: $tmp5"
  
loop:
  ;call checkForCancelAndQuit
     call increaseAndLoopProgressBar
  StrCmp $1 "" done
  ${GetFileAttributes} "$ftp_path\$1" DIRECTORY $2
  IntCmp $2 1 isdir
;retry: ;this add a file to the FTPList of files to upload
  strcmp "$ftp_path\$1" "$ftp_pathOrig\ver$maskExtension" cont ;ignore this file for now
  ;nxs::Update /NOUNLOAD /sub "$\rScanning files for mirror: $tmp5 ...$\rFile: $1" /pos $progressBarPos /end  
  ;//A NEW FILE WAS FOUND
   ;Add it to Uploaded Snapshot
   md5dll::GetMD5File "$ftp_path\$1"
   Pop $3
   ;MessageBox MB_OK "Added to snapshot $ftp_path\$1:$3"
   filewrite $uploadedSnapshot_New "$ftp_path\$1:$3$\r$\n"
    ;MessageBox MB_OK "$1:$3"   
   ;Check Prev Uploaded Snapshot if not to upload this again
   strcmp $onlyUploadChangedFiles "1" 0 loop_fileDoAdd
   fileopen $uploadedSnapshot_Prev $uploadedSnapshot_Prev_Path r ;open previous Uploaded snap
    loop_scanPrevSnapshot_loop:
     clearerrors
     fileread $uploadedSnapshot_Prev $4
     iferrors 0 +3 ;endOfFile, not found, so add it
      fileclose $uploadedSnapshot_Prev
      goto loop_fileDoAdd 
     strcmp $4 "$ftp_path\$1:$3$\r$\n" 0 loop_scanPrevSnapshot_loop ;if current line is the same current line we just added to the new snap (our curFile:MD5)
      !insertmacro WRITELN " -Skipped: $1 (No change since last upload)"
      goto cont 
 loop_fileDoAdd:
  ;MessageBox MB_OK "Sched Upload of $ftp_path\$1:$3"   
  ;Add it to the ftpListFile (uploaded after all mirrors contributed their files)  
  FileWrite $ftp_ListFile "$ftp_url/$1$\r$\n" ;ftp url
  FileWrite $ftp_ListFile "$ftp_path\$1$\r$\n" ;local path
  IntOp $ftp_intFilesToUpload $ftp_intFilesToUpload + 1  
  Goto cont
  ;//END of New File Found
isdir: ;this will transverse a folder
  StrCmp $1 . cont
  StrCmp $1 .. cont
  Push $ftp_path
  Push $ftp_url
  StrCpy $ftp_path "$ftp_path\$1"
  StrCpy $ftp_url "$ftp_url/$1"
  Call enumerateDirToFTPList
  Pop $ftp_url
  Pop $ftp_path
cont:
  FindNext $0 $1
  Goto loop
done:    
  FindClose $0
  
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Pop $0

FunctionEnd

Function ftpall_doUpload
  Push $0 ; uploadURL
  Push $1 ; localFileToUpload
  Push $2 ; successStatus
 strcpy $progressBarPos 0  
 
 uploadLoop:
  ;call checkForCancelAndQuit_IgnoreProgressBar
  
  IntOp $progressBarPos $progressBarPos + 1
  fileread $ftp_ListFile $0
  strcpy $0 $0 -2 ;kill newLine
   strcmp $0 "" done
  fileread $ftp_ListFile $1
  strcpy $1 $1 -2 ;kill newLine
  !insertmacro WRITELN " Uploading file ($progressBarPos/$ftp_intFilesToUpload): $1"
  ;nxs::Update /NOUNLOAD /sub "Uploading file: $1" /pos $progressBarPos /max $ftp_intFilesToUpload /end
  
 retry:
  ;MessageBox MB_OK "[0:$0 1:$1]"  
  ;Inetc::put $0 "$1" /end ;Inetc sucks at uploading to subdirs, even if they exist. Just try FileAve.com  
  !insertmacro FTP_URL_FIX_USERPASS $0 ;fixes ftp url up to fix usern@me bug    
  nsExec::ExecToStack '"$EXEDIR\..\Contrib\curl.exe" -T "$1" "$0" --ftp-create-dirs' ;Yay for ftp-create-dirs!
  Pop $2
  ;DetailPrint "$2 $1"  
  StrCmp $2 "0" uploadLoop ; for nsexec: ;StrCmp $2 "OK" uploadLoop
   Pop $2  
   ${WordFind} $2 ") " "+1}" $2
   strcpy $2 $2 -2
   !insertmacro WRITELN "  File upload failed ($2): $0. Retry? NOTE: To answer this question, look for a message box behind this window! Sorry."
   MessageBox MB_YESNO "File upload failed ($2): $0. Retry?" IDYES retry ;;CRASH? - inetc was crashy, not Curl
    push "Could not upload file: $1 to $0"
    call failQuitMsg
 done:
  Pop $2
  Pop $1
  Pop $0
FunctionEnd

;;;;;;

; GetParameters
 ; input, none
 ; output, top of stack (replaces, with e.g. whatever)
 ; modifies no other variables.

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
 
;taken from http://nsis.sourceforge.net/Manage_dates_as_numbers#Date2Serial
Function TodaySerial
  Call Today
  Exch 2
  Call Date2Serial
FunctionEnd

Function Today
  System::Alloc 128
  Pop $0
  System::Call "Kernel32::GetSystemTime(i) v (r0)"
  System::Call "*$0(&i2 .r1, &i2 .r2, &i2 .r3, &i2 .r4, &i2 .r5, &i2 .r6, &i2 .r7, &i2 .r8)"
  System::Free $0
 
  Push $1
  Push $2
  Push $4
FunctionEnd

Function Date2Serial
  Pop $R0 ;year
  Pop $R1 ;month
  Pop $R2 ;day
  IntOp $R3 0 + 1
  Loop:
    IntCmp $R1 $R3 OutLoop 
    Push $R3
    Push $R0
    Call DaysInMonth
    Pop $R4
    IntOp $R2 $R2 + $R4
    IntOp $R3 $R3 + 1
    Goto Loop
  OutLoop:
    IntOp $R3 $R0 - 1
    IntOp $R5 $R3 * 365
    IntOp $R6 $R3 / 4
    IntOp $R5 $R5 + $R6
    IntOp $R6 $R3 / 100
    IntOp $R5 $R5 - $R6
    IntOp $R6 $R3 / 400
    IntOp $R5 $R5 + $R6
    IntOp $R5 $R5 + $R2
    IntOp $R5 $R5 - 693594
    Push $R5
FunctionEnd

Function DaysInMonth
  Pop $0 ;annee
  Pop $1 ;mois
 
  IntCmp $1 1 m31
  IntCmp $1 2 m28
  IntCmp $1 3 m31
  IntCmp $1 4 m30
  IntCmp $1 5 m31
  IntCmp $1 6 m30
  IntCmp $1 7 m31
  IntCmp $1 8 m31
  IntCmp $1 9 m30
  IntCmp $1 10 m31
  IntCmp $1 11 m30
  IntCmp $1 12 m31
 
  m31:
    Push 31
    Goto end
  m30:
    Push 30
    Goto end
  m28:
    Push $0
    Call IsLeapYear
    Pop $0
    IntCmp $0 1 m29
      Push 28
      Goto end
    m29:
     Push 29
  end:
FunctionEnd

Function IsLeapYear
  Pop $0
  IntOp $1 $0 % 4
  IntCmp $1 0 test2
  Goto ko
  test2:
    IntOp $1 $0 % 100
    IntCmp $1 0 test3
    Goto ok
  test3:
    IntOp $1 $0 % 400
    IntCmp $1 0 ok
    Goto ko
  ok:
    Push 1
    Goto end
  ko:
    Push 0
  end:
FunctionEnd

;Push "String to do replacement in (haystack)"
;Push "String to replace (needle)"
;Push "Replacement"
;Call StrRep
;Pop "$R0" ;result
Function StrRep
  Exch $R4 ; $R4 = Replacement String
  Exch
  Exch $R3 ; $R3 = String to replace (needle)
  Exch 2
  Exch $R1 ; $R1 = String to do replacement in (haystack)
  Push $R2 ; Replaced haystack
  Push $R5 ; Len (needle)
  Push $R6 ; len (haystack)
  Push $R7 ; Scratch reg
  StrCpy $R2 ""
  StrLen $R5 $R3
  StrLen $R6 $R1
loop:
  StrCpy $R7 $R1 $R5
  StrCmp $R7 $R3 found
  StrCpy $R7 $R1 1 ; - optimization can be removed if U know len needle=1
  StrCpy $R2 "$R2$R7"
  StrCpy $R1 $R1 $R6 1
  StrCmp $R1 "" done loop
found:
  StrCpy $R2 "$R2$R4"
  StrCpy $R1 $R1 $R6 $R5
  StrCmp $R1 "" done loop
done:
  StrCpy $R3 $R2
  Pop $R7
  Pop $R6
  Pop $R5
  Pop $R2
  Pop $R1
  Pop $R4
  Exch $R3
FunctionEnd

;Call CreateGUID
;Pop $0 ;contains GUID
Function CreateGUID
  System::Call 'ole32::CoCreateGuid(g .s)'
FunctionEnd