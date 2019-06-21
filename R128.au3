#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Icons\peakmeter.ico
#AutoIt3Wrapper_Res_Comment=Measure loudness with ffmpeg according to R128.
#AutoIt3Wrapper_Res_Description=Measure loudness with ffmpeg according to R128.
#AutoIt3Wrapper_Res_Fileversion=1.0.0.8
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_CompanyName=Norddeutscher Rundfunk
#AutoIt3Wrapper_Res_LegalCopyright=Conrad Zelck
#AutoIt3Wrapper_Res_SaveSource=y
#AutoIt3Wrapper_Res_Language=1031
#AutoIt3Wrapper_Res_Field=Copyright|Conrad Zelck
#AutoIt3Wrapper_Res_Field=Compile Date|%date% %time%
#AutoIt3Wrapper_AU3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w- 7
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/mo
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <AutoItConstants.au3>
#include <Date.au3>
#include <FileConstants.au3>
#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
#include <StaticConstants.au3>
#include <TrayCox.au3> ; source: https://github.com/SimpelMe/TrayCox - not needed for functionality

FileDelete(@TempDir & '\output.wav')
FileInstall('K:\ffmpeg\bin\ffmpeg.exe', @TempDir & "\ffmpeg.exe", $FC_OVERWRITE)
Local $sPathFFmpeg = @TempDir & "\"
Global $g_sStdErrAll
Local $bSendTo = False

Local $sFile
;~ Local $sFile = "T:\Maus\VPN\AUDIO~4T~\zelckc\Test.mxf"
;~ Local $sFile = "M:\Ue_Schnitt_Ton\ton_fertig\G59031_005_Film-Tip-Wie-vi_E_190612_DAS18_M02_B.mxf"
;~ Local $sFile = "M:\Ue_Schnitt_Ton\ton_fertig\G55969_002_Die-wunderbare-_S_190610_E1440_MS1_B.mxf"

If FileExists($cmdlineraw) Then
	$sFile = $cmdlineraw
	$bSendTo = True
Else
	$sFile = FileOpenDialog("Choose a file", "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}", "Alle (*.*)", $FD_FILEMUSTEXIST)
	If @error Then
		MsgBox($MB_TOPMOST, "Error", "File selection failed" & @CRLF & @CRLF & "Program exits.")
		Exit
	EndIf
EndIf

Local $iTrackL = 1
Local $iTrackR = 2
If Not $bSendTo Then
	GUICreate("Tracks", 300, 50)
	Local $idTracks12 = GUICtrlCreateRadio("1+2", 10, 10, 50, 30)
	GUICtrlSetState(-1, $GUI_CHECKED)
	Local $idTracks34 = GUICtrlCreateRadio("3+4", 60, 10, 50, 30)
	Local $idTracks56 = GUICtrlCreateRadio("5+6", 110, 10, 50, 30)
	Local $idTracks78 = GUICtrlCreateRadio("7+8", 160, 10, 50, 30)
	Local $idButtonOK = GUICtrlCreateButton("OK", 210, 10, 80, 30, $BS_DEFPUSHBUTTON)
	GUISetState(@SW_SHOW)

	While 1
		Switch GUIGetMsg()
			Case $GUI_EVENT_CLOSE
				Exit
			Case $idButtonOK
				ExitLoop
			Case $idTracks12
				$iTrackL = 1
				$iTrackR = 2
			Case $idTracks34
				$iTrackL = 3
				$iTrackR = 4
			Case $idTracks56
				$iTrackL = 5
				$iTrackR = 6
			Case $idTracks78
				$iTrackL = 7
				$iTrackR = 8
		EndSwitch
	WEnd
	GUIDelete()
EndIf
ConsoleWrite("L: " & $iTrackL & @CRLF)
ConsoleWrite("R: " & $iTrackR & @CRLF)

GUICreate("R128", 600, 270)
GUICtrlCreateLabel(_FileName($sFile), 10, 10, 580, 30)
GUICtrlSetFont(-1, 14, 400, 0, "Courier New")
GUICtrlCreateLabel("Extract Audio:", 10, 50, 580, 30)
GUICtrlSetFont(-1, 12, 400, 0, "Courier New")
Global $Progress1 = GUICtrlCreateProgress(10, 80, 580, 20)
GUICtrlCreateLabel("Loudness Audio:", 10, 120, 580, 30)
GUICtrlSetFont(-1, 12, 400, 0, "Courier New")
Global $Progress2 = GUICtrlCreateProgress(10, 150, 580, 20)
Global $Edit = GUICtrlCreateLabel("", 10, 200, 420, 90)
GUICtrlSetFont(-1, 14, 400, 0, "Courier New")
Local $g_hLabelRunningTime = GUICtrlCreateLabel("", 440, 200, 150, 30, $SS_CENTER)
GUICtrlSetFont(-1, 14, 400, 0, "Courier New")
Local $idButton = GUICtrlCreateButton("Copy Data", 440, 230, 150, 30)
GUICtrlSetFont(-1, 12, 400, 0, "Courier New")
GUICtrlSetState(-1, $GUI_DISABLE)
GUISetState(@SW_SHOW)

Global $hTimerStart = TimerInit()

Local $sCommand = '-i "' & $sFile & '" -filter_complex "[0:' & $iTrackL & '][0:' & $iTrackR & '] amerge" -c:a pcm_s24le -y ' & @TempDir & '\output.wav'
_runFFmpeg('ffmpeg ' & $sCommand, $sPathFFmpeg, 1)
GUICtrlSetData($Progress1, 100) ; if ffmpeg is done than set progress to 100 - sometimes last StderrRead with 100 is missed

If Not FileExists(@TempDir & '\output.wav') Then ; error
	GUICtrlSetData($Edit, "Error: Could not extract audio.")
Else
	$sCommand = '-i "' & @TempDir & '\output.wav" -filter_complex ebur128=framelog=verbose:peak=true -f null -'
	_runFFmpeg('ffmpeg ' & $sCommand, $sPathFFmpeg, 2)
	GUICtrlSetData($Progress2, 100) ; if ffmpeg is done than set progress to 100 - sometimes last StderrRead with 100 is missed

	GUICtrlSetData($Edit, _GetR128($g_sStdErrAll))
	GUICtrlSetState($idButton, $GUI_ENABLE)
EndIf
WinActivate("R128","")

While 1
	Switch GUIGetMsg()
		Case $GUI_EVENT_CLOSE
			ExitLoop
		Case $idButton
			ClipPut($sFile & @CRLF & @CRLF & GUICtrlRead($Edit) & @CRLF & @CRLF & "measurement time: " & StringRegExpReplace(GUICtrlRead($g_hLabelRunningTime), "\W", ""))
	EndSwitch
WEnd
Exit

Func _runFFmpeg($command , $wd, $iProgress)
	Local $hPid = Run('"' & @ComSpec & '" /c ' & $command, $wd, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
	Local $sStdErr, $sTimer
	Local $iTicksDuration = 0, $iTicksTime = 0, $iTimer
	While 1
		Sleep(500)
		$sStdErr = StderrRead($hPid)
		If @error Then ExitLoop
		$g_sStdErrAll &= $sStdErr
		If StringLen($sStdErr) > 0 Then
			If Not $iTicksDuration Then $iTicksDuration = _GetDuration($sStdErr)
			$iTicksTime = _GetTime($sStdErr)
			If Not @error Then $sStdErr = ""
			Switch $iProgress
				Case 1
					GUICtrlSetData($Progress1, $iTicksTime * 100 / $iTicksDuration)
				Case 2
					GUICtrlSetData($Progress2, $iTicksTime * 100 / $iTicksDuration)
			EndSwitch
		EndIf
		$iTimer = TimerDiff($hTimerStart)
		$sTimer = _Zeit($iTimer)
		If GUICtrlRead($g_hLabelRunningTime) <> $sTimer Then
			GUICtrlSetData($g_hLabelRunningTime, $sTimer)
		EndIf
	WEnd
EndFunc

Func _GetDuration($sStdErr)
    If Not StringInStr($sStdErr, "Duration:") Then Return SetError(1, 0, 0)
    Local $aRegExp = StringRegExp($sStdErr, "(?i)Duration.+?([0-9:]+)", 3)
    If @error Or Not IsArray($aRegExp) Then Return SetError(2, 0, 0)
    Local $sTime = $aRegExp[UBound($aRegExp) - 1]
    Local $aTime = StringSplit($sTime, ":", 2)
    If @error Or Not IsArray($aTime) Then Return SetError(3, 0, 0)
    Return _TimeToTicks($aTime[0], $aTime[1], $aTime[2])
EndFunc   ;==>_GetDuration

Func _GetTime($sStdErr)
    If Not StringInStr($sStdErr, "time=") Then Return SetError(1, 0, 0)
    Local $aRegExp = StringRegExp($sStdErr, "(?i)time.+?([0-9:]+)", 3)
    If @error Or Not IsArray($aRegExp) Then Return SetError(2, 0, 0)
    Local $sTime = $aRegExp[UBound($aRegExp) - 1]
    Local $aTime = StringSplit($sTime, ":", 2)
    If @error Or Not IsArray($aTime) Then Return SetError(3, 0, 0)
    Return _TimeToTicks($aTime[0], $aTime[1], $aTime[2])
EndFunc   ;==>_GetTime

Func _GetR128($sStdErr)
    If Not StringInStr($sStdErr, "Integrated loudness:") Then Return SetError(1, 0, "Fehler")
    Local $aRegExp = StringRegExp($sStdErr, "(?isU)Integrated loudness:.*(I:.*LUFS).*(LRA:.*LU).*\h\h(Peak:.*dBFS)", 3)
    If @error Or Not IsArray($aRegExp) Then Return SetError(2, 0, "Fehler")
	Local $iUbound = UBound($aRegExp)
    Return $aRegExp[$iUbound -3] & @CRLF & $aRegExp[$iUbound - 2] & @CRLF & $aRegExp[$iUbound - 1]
EndFunc   ;==>_GetR128

Func _FileName($sFullPath)
	Local $iDelimiter = StringInStr($sFullPath, "\", 0, -1)
	Return StringTrimLeft($sFullPath, $iDelimiter)
EndFunc

Func _Zeit($iMs, $bComfortView = True) ; from ms to a format: "12h 36m 56s 13f" (with special space between - ChrW(8239))
	Local $sReturn
	$iMs = Int($iMs)
	Local $iFrames, $iMSec, $iSec, $iMin, $iHour, $sSign
	If $iMs < 0 Then
		$iMs = Abs($iMs)
		$sSign = '-'
	EndIf
	$iMSec = StringRight($iMs, 3)
	$iFrames = $iMSec / 40
	$iSec = $iMs / 1000
	$iMin = $iSec / 60
	$iHour = $iMin / 60
	$iMin -= Int($iHour) * 60
	$iSec -= Int($iMin) * 60
	If $bComfortView Then ; no hours if not present and no frames
		If Not Int($iHour) = 0 Then $sReturn &= StringRight('0' & Int($iHour), 2) & 'h' & ChrW(8239)
		$sReturn &= StringRight('0' & Int($iMin), 2) & 'm' & ChrW(8239)
		If Int($iHour) = 0 Then $sReturn &= StringRight('0' & Int($iSec), 2) & 's' ; zum DEBUGGING auskommentieren
	Else
		$sReturn = $sSign & StringRight('0' & Int($iHour), 2) & 'h' & ChrW(8239) & StringRight('0' & Int($iMin), 2) & 'm' & ChrW(8239) & StringRight('0' & Int($iSec), 2) & 's' & ChrW(8239) & StringRight('0' & Int($iFrames), 2) & 'f'
	EndIf
	Return $sReturn
EndFunc   ;==>_Zeit