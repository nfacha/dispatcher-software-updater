!ifndef DISPATCHER_NAME
;Sample values of what PUD will be passing
!define DISPATCHER_NAME "MySoftware" ;Required
!define DISPATCHER_VERSION "v1.0"
!define DISPATCHER_RELEASEPATH "c:\Some\Other\Path" ;Required
!define DISPATCHER_BRUNEXE "1"
!define DISPATCHER_EXEPATH "MySoftware.exe"
!define DISPATCHER_ICOPATH "MySoftware.exe" ;this is just set to the relative path of what the Updater will Run (if that is blank, the icon of EXEPath is used)

!define DISPATCHER_LICENSE "C:\Path\License.txt"
!define DISPATCHER_STARTMENUGROUP "Puchisoft\MySoftware" ;Required
!define DISPATCHER_BUPDATERSHORTCUT "1" ;bExists, doesn't matter what it's value is
!define DISPATCHER_BDESKTOPSHORTCUT "1"
!define DISPATCHER_INSTOUTPATH "C:\Installer.exe" ;Required
!define DISPATCHER_WEBSITE "http://www.puchisoft.com"
!endif


!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DISPATCHER_NAME}"
!define PRODUCT_PUBLISHER "Puchisoft, Inc."
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

SetCompressor /SOLID lzma
brandingtext "Puchisoft Dispatcher"
ShowInstDetails hide
ShowUnInstDetails hide
; MUI 1.67 compatible ------
!include "MUI.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\orange-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\orange-uninstall.ico"

; Welcome page
!insertmacro MUI_PAGE_WELCOME
; License page
!ifdef DISPATCHER_LICENSE
  !insertmacro MUI_PAGE_LICENSE "${DISPATCHER_LICENSE}"
!endif
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES
; Finish page
!ifdef DISPATCHER_EXEPATH
 !ifdef DISPATCHER_BRUNEXE
  !define MUI_FINISHPAGE_RUN "$INSTDIR\${DISPATCHER_EXEPATH}"
 !endif
!endif
;!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\Readme.txt"
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"

; Reserve files
!insertmacro MUI_RESERVEFILE_INSTALLOPTIONS

; MUI end ------

Name "${DISPATCHER_NAME} ${DISPATCHER_VERSION}"
OutFile "${DISPATCHER_INSTOUTPATH}"
InstallDir "$PROGRAMFILES\${DISPATCHER_STARTMENUGROUP}"
RequestExecutionLevel admin

Section "MainSection" SEC01
  SetOutPath "$INSTDIR"
  SetOverwrite on    
  File /r "${DISPATCHER_RELEASEPATH}\"
  

  createdirectory "$SMPROGRAMS\${DISPATCHER_STARTMENUGROUP}\"
!ifdef DISPATCHER_EXEPATH
  ;don't overwrite icon of exe that shortcut is too if DISPATCHER_ICOPATH is blank
  strcpy $0 "" ;either blank
  strcmp "${DISPATCHER_ICOPATH}" "" +2
   strcpy $0 "$INSTDIR\${DISPATCHER_ICOPATH}" ;or correct path to non-Updater exe; (may not equal a bad path like just the $INSTALDIR without a rel exe path)
  CreateShortCut  "$SMPROGRAMS\${DISPATCHER_STARTMENUGROUP}\${DISPATCHER_NAME}.lnk" "$INSTDIR\${DISPATCHER_EXEPATH}" "" "$0"  
 
 !ifdef DISPATCHER_BUPDATERSHORTCUT   
   CreateShortCut  "$SMPROGRAMS\${DISPATCHER_STARTMENUGROUP}\${DISPATCHER_NAME} - Check for Updates.lnk" "$INSTDIR\Updater.exe" "-check"; "$0" ;this adds the program's icon, reguardless of which EXE 
 !endif
 !ifdef DISPATCHER_BDESKTOPSHORTCUT
   CreateShortCut "$DESKTOP\${DISPATCHER_NAME}.lnk" "$INSTDIR\${DISPATCHER_EXEPATH}" "" "$0"
 !endif
!endif 

!ifdef DISPATCHER_WEBSITE  
  WriteIniStr "$INSTDIR\${DISPATCHER_NAME}.url" "InternetShortcut" "URL" "${DISPATCHER_WEBSITE}"
  CreateShortCut "$SMPROGRAMS\${DISPATCHER_STARTMENUGROUP}\Website.lnk" "$INSTDIR\${DISPATCHER_NAME}.url"
!endif
  CreateShortCut "$SMPROGRAMS\${DISPATCHER_STARTMENUGROUP}\Uninstall.lnk" "$INSTDIR\uninst.exe"
SectionEnd

Section -Post
  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "${DISPATCHER_NAME}" ;WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\${DISPATCHER_EXEPATH}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${DISPATCHER_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${DISPATCHER_WEBSITE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
SectionEnd


Function un.onUninstSuccess
  HideWindow
  MessageBox MB_ICONINFORMATION|MB_OK "$(^Name) was successfully removed from your computer."
FunctionEnd

Function un.onInit
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Are you sure you want to completely remove $(^Name) and all of its components?" IDYES +2
  Abort
FunctionEnd

Section Uninstall
!ifdef   DISPATCHER_BDESKTOPSHORTCUT
  Delete "$DESKTOP\${DISPATCHER_NAME}.lnk"
!endif
  
  RMDir /r /REBOOTOK "$SMPROGRAMS\${DISPATCHER_STARTMENUGROUP}\"
  RMDir /r /REBOOTOK "$INSTDIR"

  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
  SetAutoClose true
SectionEnd