Name "PUD - Make Date Incl"
OutFile "MakeDataIncl.exe"
Caption "PUD - Make Date Incl" ;Change title
BrandingText "www.puchisoft.com"
SubCaption 3 " " ;Gets rid of stupid "Installing..." addon title
SubCaption 4 " " ;Gets rid of stupid "Installing..." addon title
;Icon "${NSISDIR}\Contrib\Graphics\Icons\box-install.ico"
RequestExecutionLevel admin
ShowInstDetails show
autoclosewindow true


!include "FileFunc.nsh" ;only for GetTime
!insertmacro GetTime

var newVer
var theDate
var editionName

Function .onInit
setsilent silent
FunctionEnd

Section
clearerrors
;;;;;;;;;;;;;;;;;;;;;
;; Determine Version
;;;;;;;;;;;;;;;;;;;;;


${GetTime} "" "LS" $0 $1 $2 $3 $4 $5 $6
strcpy $newVer "v$2.$1.$0" ;The format is Year.Month.Day.BUILD, where Build is incremented each release
strcpy $theDate "$1/$0/$2 (MM/DD/YYYY)"

;read in Edition Name from PSUpdateDeployer.dat
FileOpen $9 "$EXEDIR\..\Dispatcher.dat" r
FileRead $9 $editionName
FileClose $9

;make installer includes (for product ver in title)
FileOpen $9 "$EXEDIR\installer_includes.nsh" w
FileWrite $9 '!define PRODUCT_VERSION "$newVer"$\r$\n'
FileWrite $9 '!define PRODUCT_EDITION "$editionName"$\r$\n'
FileClose $9

;make Data\Updater.ver, included in everyone Updater.dat for the sake of updater update checking
 Push $0 ; day
 Push $1 ; month
 Push $2 ; year
 Call Date2Serial
 Pop $3 ;serial 39324
 ;3) Combine everything into Stamp file
 strcpy $8 "$3.$4.$5.$6"
 ;MessageBox MB_OK "stamp $9"
 FileOpen $9 "$EXEDIR\..\Data\Updater.ver" w
 FileWrite $9 "[Updater]$\r$\n"
 FileWrite $9 "Stamp=$8"
 FileClose $9

goto zend

;;;;Failure
failure:
;KillProcDLL::KillProc "ShipIt.exe"
;MessageBox MB_OK "Shipment failed."
goto zend

;;;;Done
zend:
SectionEnd


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