Function CharStrip
Exch $R0 #char
Exch
Exch $R1 #in string
Push $R2
Push $R3
Push $R4
 StrCpy $R2 -1
 IntOp $R2 $R2 + 1
 StrCpy $R3 $R1 1 $R2
 StrCmp $R3 "" +8
 StrCmp $R3 $R0 0 -3
  StrCpy $R3 $R1 $R2
  IntOp $R2 $R2 + 1
  StrCpy $R4 $R1 "" $R2
  StrCpy $R1 $R3$R4
  IntOp $R2 $R2 - 2
  Goto -9
  StrCpy $R0 $R1
Pop $R4
Pop $R3
Pop $R2
Pop $R1
Exch $R0
FunctionEnd
!macro CharStrip Char InStr OutVar
 Push '${InStr}'
 Push '${Char}'
  Call CharStrip
 Pop '${OutVar}'
!macroend
!define CharStrip '!insertmacro CharStrip'
 
Function StrStrip
Exch $R0 #string
Exch
Exch $R1 #in string
Push $R2
Push $R3
Push $R4
Push $R5
 StrLen $R5 $R0
 StrCpy $R2 -1
 IntOp $R2 $R2 + 1
 StrCpy $R3 $R1 $R5 $R2
 StrCmp $R3 "" +9
 StrCmp $R3 $R0 0 -3
  StrCpy $R3 $R1 $R2
  IntOp $R2 $R2 + $R5
  StrCpy $R4 $R1 "" $R2
  StrCpy $R1 $R3$R4
  IntOp $R2 $R2 - $R5
  IntOp $R2 $R2 - 1
  Goto -10
  StrCpy $R0 $R1
Pop $R5
Pop $R4
Pop $R3
Pop $R2
Pop $R1
Exch $R0
FunctionEnd
!macro StrStrip Str InStr OutVar
 Push '${InStr}'
 Push '${Str}'
  Call StrStrip
 Pop '${OutVar}'
!macroend
!define StrStrip '!insertmacro StrStrip'


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


!define StrRep "!insertmacro StrRep"
!macro StrRep output string old new
    Push "${string}"
    Push "${old}"
    Push "${new}"
    !ifdef __UNINSTALL__
        Call un.StrRep
    !else
        Call StrRep
    !endif
    Pop ${output}
!macroend
 
!macro Func_StrRep un
    Function ${un}StrRep
        Exch $R2 ;new
        Exch 1
        Exch $R1 ;old
        Exch 2
        Exch $R0 ;string
        Push $R3
        Push $R4
        Push $R5
        Push $R6
        Push $R7
        Push $R8
        Push $R9
 
        StrCpy $R3 0
        StrLen $R4 $R1
        StrLen $R6 $R0
        StrLen $R9 $R2
        loop:
            StrCpy $R5 $R0 $R4 $R3
            StrCmp $R5 $R1 found
            StrCmp $R3 $R6 done
            IntOp $R3 $R3 + 1 ;move offset by 1 to check the next character
            Goto loop
        found:
            StrCpy $R5 $R0 $R3
            IntOp $R8 $R3 + $R4
            StrCpy $R7 $R0 "" $R8
            StrCpy $R0 $R5$R2$R7
            StrLen $R6 $R0
            IntOp $R3 $R3 + $R9 ;move offset by length of the replacement string
            Goto loop
        done:
 
        Pop $R9
        Pop $R8
        Pop $R7
        Pop $R6
        Pop $R5
        Pop $R4
        Pop $R3
        Push $R0
        Push $R1
        Pop $R0
        Pop $R1
        Pop $R0
        Pop $R2
        Exch $R1
    FunctionEnd
!macroend
!insertmacro Func_StrRep ""
!insertmacro Func_StrRep "un."

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

Function TodaySerial
  Call Today
  Exch 2
  Call Date2Serial
FunctionEnd