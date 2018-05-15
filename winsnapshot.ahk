#NoEnv
#Persistent
#SingleInstance Force

SetTitleMatchMode, 2

; ============================== INIT START =======================================

; Get name of script and find matching icon
Menu, tray, icon, winsnapshot.dll, 2

; Load timer
SetTimer, fnWindowPos, 1000

#Include progress.ahk


SC_MONITORPOWER := 0xF170
POWER_ON	:= -1
POWER_LOW	:= 1
POWER_OFF	:= 2
OnMessage( SC_MONITORPOWER, POWER_ON, "windowRestore" )
OnMessage( SC_MONITORPOWER, POWER_LOW, "windowSnapshot" )
OnMessage( SC_MONITORPOWER, POWER_OFF, "windowSnapshot" )
WS_VISIBLE := 0x10000000

arrWin 	:= object()
blnRestoring := false
strLog 	:= "winsnapshot.log"
intState := 3 ; 1 = unlocked, 2 = locked, 3 = restored
intCounter := 0

strLock := "lock.log"
FileDelete, %strLock%
; =============================== INIT END ========================================
; ============================= HOTKEYS START =====================================


fnWindowPos:
	global blnRestoring, intState, intCounter

	; Check to see if workstation is locked
	if ( !DllCall("User32\OpenInputDesktop","int",0*0,"int",0*0,"int",0x0001L*1) ) {
		; Yes it's locked
		if ( intState != 2 ) {
			FileAppend, % "`nLocked," A_Now, %strLock%
			intState := 2
		}
	} else {
		; No it's unlocked
		if ( intState = 2 ) {
			FileAppend, % "`nRestored," A_Now, %strLock%
			intState := 3
			windowRestore()
		} else {
			if ( intState = 3 ) {
				FileAppend, % "`nUnlocked," A_Now, %strLock%
				intState := 1
			}
			if ( 0 = intCounter ) {
				;FileAppend, % "`nSnapshot," A_Now, %strLock%
				windowSnapshot()
			}
		}
	}

	if ( 30 = intCounter ) {
		intCounter := 0
	} else {
		intCounter++
	}
return


/**
 * Grab x,y,w,h for each window, minimized or not, and write to memory (and write to file)
 * @todo write them to log file
 */
windowSnapshot() {
	DetectHiddenWindows Off
	global arrWin, strLog

	; Delete the log file then start again
	FileDelete, %strLog%
	FileAppend, % "Action,idWin,x,y,w,h,timestamp", %strLog%

	; Empty window array so we don't keep accumulating thousands of snapshots per window
	arrWin := {}

	; Capture window sizes and positions
	WinGet, id, list,,, Program Manager
	Loop, %id% {
		; Flash tray icon to show recording
		if ( Mod( A_Index, 2 ) ) {
			Menu, tray, icon, winsnapshot.dll, 1
		} else {
			Menu, tray, icon, winsnapshot.dll, 2
		}

		idWin := id%A_Index%
		; Get window visibility status, and continue if visible
		winGet, hexStyle, Style, ahk_id %idWin%

		WinGetTitle, strTitle, ahk_id %idWin%

		; Get window position and size and continue if present
		WinGetPos, intX, intY, intW, intH, ahk_id %idWin%
		;if ( ( 0 = intX && 0 = intY && 0 = intW && 0 = intY ) || ( 0 > intX || 0 > intY || 0 > intW || 0 > intY ) ) {
			;Continue
		;} else {
			;WinGetTitle, strWin, ahk_id %idWin% 
			;MsgBox % strWin " is " blnVisible "`nX: " intX "`nY: " intY "`nW: " intW "`nH: " intH
			FileAppend, % "`nSnapshot," idWin "," intX "," intY "," intW "," intH "," A_Now "," strTitle, %strLog%

			arrPos := [ idWin, intX, intY, intW, intH ]
			arrWin.insert( arrPos )
		;}
	}

	; Reset tray icon to default
	Menu, tray, icon, winsnapshot.dll, 2
}


/**
 * Restore windows to saved positions and sizes
 * @todo read from log file so persists across reboots
 */
windowRestore() {
	global arrWin, strLog, blnRestoring

	objProgress := new Progress( 1, arrWin.maxIndex(), "Restoring...", "WinSnapshot" )

	For key, arrPos in arrWin {
		; Flash tray icon to show recording
		if ( Mod( A_Index, 2 ) ) {
			Menu, tray, icon, winsnapshot.dll, 3
		} else {
			Menu, tray, icon, winsnapshot.dll, 2
		}

		;MsgBox % arrPos[1] " is`nX: " arrPos[2] "`nY: " arrPos[3] "`nW: " arrPos[4] "`nH: " arrPos[5]
		FileAppend, % "`nRestore," arrPos[1] "," arrPos[2] "," arrPos[3] "," arrPos[4] "," arrPos[5] "," A_Now , %strLog%

		idWin := arrPos[1]
		intX  := arrPos[2]
		intY  := arrPos[3]
		intW  := arrPos[4]
		intH  := arrPos[5]
		WinMove, ahk_id %idWin%, , %intX%, %intY%, %intW%, %intH%

		objProgress.update( A_Index, "Restoring window: " idWin )
	}

	; Snapshot again now windows have (hopefully) all been put back
	windowSnapshot()

	; Reset tray icon to default
	Menu, tray, icon, winsnapshot.dll, 2
}
