;WARNING: Don't use this! AVG is retarded and thinks this is a virus
;Instead, same code has been implimented into Compiler.exe to replace this file

Name "EXE Proxy"
OutFile "EXEProxy.exe"
Caption "EXE Silence Proxy" ;Change title
BrandingText "www.puchisoft.com"
SubCaption 3 " " ;Gets rid of stupid "Installing..." addon title
SubCaption 4 " " ;Gets rid of stupid "Installing..." addon title
;Icon "${NSISDIR}\Contrib\Graphics\Icons\box-install.ico"
ShowInstDetails show

!include "WordFunc.nsh" ;aka. String parser ;)
!insertmacro WordFind


autoclosewindow true

Function .onInit
setsilent silent
Call GetParameters
 Pop $0
 
 ${WordFind} $EXEFILE "." "+1" $1
 ;MessageBox MB_OK "$1_.exe $0"
 nsExec::ExecToLog "$1_.exe $0"
 
FunctionEnd

Section
SectionEnd




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