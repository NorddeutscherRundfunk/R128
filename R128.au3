#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Icons\peakmeter.ico
#AutoIt3Wrapper_Res_Comment=Measure loudness with ffmpeg according to R128.
#AutoIt3Wrapper_Res_Description=Measure loudness with ffmpeg according to R128.
#AutoIt3Wrapper_Res_Fileversion=1.1.0.21
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=p
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
#include <ButtonConstants.au3>
#include <Date.au3>
#include <FileConstants.au3>
#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
#include <StaticConstants.au3>
#include <StringConstants.au3>
#include <TrayCox.au3> ; source: https://github.com/SimpelMe/TrayCox - not needed for functionality

FileInstall('K:\ffmpeg\bin\ffmpeg.exe', @TempDir & "\ffmpeg.exe", $FC_OVERWRITE)
Local $sPathFFmpeg = @TempDir & "\"
FileInstall('K:\ffmpeg\bin\ffprobe.exe', @TempDir & "\ffprobe.exe", $FC_OVERWRITE)
Local $sPathFFprobe = @TempDir & "\"
Global $g_sStdErrAll

$cmdlineraw = StringReplace($cmdlineraw, '"', '') ; if there are spaces in filename $cmdlineraw is adding leading and trailing "
Local $sFile
If FileExists($cmdlineraw) Then
	$sFile = $cmdlineraw
Else
	$sFile = FileOpenDialog("Choose a file", "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}", "Alle (*.*)", $FD_FILEMUSTEXIST)
	If @error Then
		MsgBox($MB_TOPMOST, "Error", "File selection failed." & @CRLF & @CRLF & "Application exits.")
		Exit
	EndIf
EndIf
Local $sOutputFileWithoutExtension = _StripFileExtension(_FileName($sFile))

SplashTextOn("Be patient", "R128 is analysing file ...", 300, 50)

; how many video streams to increase stream counter
Local $sCommand = '-i "' & $sFile & '" -v 0 -show_entries stream=codec_type -of default=nw=1:nk=1'
Local $sCodecs = _runFFprobe('ffprobe ' & $sCommand, $sPathFFprobe)
ConsoleWrite("Codecs: " & $sCodecs & @CRLF)
StringReplace($sCodecs, "video", "video") ; just to get the count
Local $iCounterVideo = Number(@extended)
ConsoleWrite("Counter video: " & $iCounterVideo & @CRLF)

; is audio inside?
StringReplace($sCodecs, "audio", "audio") ; just to get the count
If @extended = 0 Then
	SplashOff()
	MsgBox($MB_TOPMOST, "Error", "No audio channels found.")
	Exit
EndIf

; channel layout for all audio streams
$sCommand = '-i "' & $sFile & '" -v 0 -select_streams a -show_entries stream=channels -of default=nw=1:nk=1'
Local $sChannels = _runFFprobe('ffprobe ' & $sCommand, $sPathFFprobe)
SplashOff()
Local $aChannels = StringSplit($sChannels, @CRLF, $STR_ENTIRESPLIT)
If Not IsArray($aChannels) Then
	MsgBox($MB_TOPMOST, "Error", "No audio channels found.")
	Exit
EndIf
For $i = 0 To $aChannels[0]
	$aChannels[$i] = Number($aChannels[$i])
Next
ConsoleWrite("Streams: " & $aChannels[0] & @CRLF)
For $i = 1 To $aChannels[0]
	ConsoleWrite("Channels: " & $aChannels[$i] & @CRLF)
Next

; are all streams mono or stereo
Local Enum $eMONO = 1, $eSTEREO, $eMULTI
Local $iMonoCount = 0, $iStereoCount = 0
Local $iLayout = 0

; only one number of channels returned
If $aChannels[0] = 1 Then
	ConsoleWrite("Only one number of channels returned: " & $aChannels[0] & @CRLF)
	$iLayout = $eMULTI
	If Mod($aChannels[1], 2) <> 0 Then $iLayout = 0 ; uneven counter
	ConsoleWrite("Multichannel: " & $aChannels[1] & @CRLF)
Else ; hope all returned channels are the same
	StringReplace($sChannels, "1", "1") ; just to get the count
	If @extended > 0 Then
		$iMonoCount = @extended
		If $iMonoCount = $aChannels[0] Then
			$iLayout = $eMONO
			If Mod($iMonoCount, 2) <> 0 Then $iLayout = 0 ; uneven counter
		EndIf
		ConsoleWrite("Monofiles: " & $iMonoCount & @CRLF)
	EndIf
	StringReplace($sChannels, "2", "2") ; just to get the count
	If @extended > 0 Then
		$iStereoCount = @extended
		If $iStereoCount = $aChannels[0] Then
			$iLayout = $eSTEREO
		EndIf
		ConsoleWrite("Stereofiles: " & $iStereoCount & @CRLF)
	EndIf
EndIf
Local $iMeasuringPairs = 0
Switch $iLayout
	Case $eMONO
		$iMeasuringPairs = $iMonoCount / 2
		ConsoleWrite("All MONO" & @CRLF)
	Case $eSTEREO
		$iMeasuringPairs = $iStereoCount
		ConsoleWrite("All STEREO" & @CRLF)
	Case $eMULTI
		$iMeasuringPairs = $aChannels[1] / 2
		ConsoleWrite("MULTI" & @CRLF)
	Case Else
		ConsoleWrite("UNDEFINED Layout" & @CRLF)
		MsgBox($MB_TOPMOST, "Error", "Track layout is undefined." & @CRLF & @CRLF & "Application exits.")
		Exit
EndSwitch

ConsoleWrite("Pairs for measuring: " & $iMeasuringPairs & @CRLF)
Local $bShowTrackSelection = True
If $iMeasuringPairs = 1 Then $bShowTrackSelection = False ; then there is no choice of tracks

Local $iTrackL = 1
Local $iTrackR = 2
If $bShowTrackSelection Then
	Local $aTrackRadios[$iMeasuringPairs * 2]
	GUICreate("Tracks", 100 + (50 * $iMeasuringPairs), 50)
	GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
	For $i = 1 To $iMeasuringPairs * 2 Step 2
		$aTrackRadios[$i] = GUICtrlCreateRadio($i & "+" & $i +1, 10 + (25 * ($i -1)), 10, 50, 30)
		GUICtrlSetOnEvent(-1, "_TrackRadioPressed")
	Next
	GUICtrlSetState($aTrackRadios[1], $GUI_CHECKED)
	Local $idButtonOK = GUICtrlCreateButton("OK", 10 + (50 * $iMeasuringPairs), 10, 80, 30, $BS_DEFPUSHBUTTON)
	GUICtrlSetOnEvent(-1, "_ExitLoop")
	GUISetState(@SW_SHOW)
	Opt("GUIOnEventMode", 1)
	Global $g_bExitLoop = False
	While Not $g_bExitLoop
		Sleep(10)
	WEnd
	Opt("GUIOnEventMode", 0)
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
Global $Edit = GUICtrlCreateLabel("", 10, 200, 260, 60)
GUICtrlSetFont(-1, 14, 400, 0, "Courier New")
Local $g_hLabelRunningTime = GUICtrlCreateLabel("", 440, 200, 150, 30, $SS_CENTER)
GUICtrlSetFont(-1, 14, 400, 0, "Courier New")
Local $idButtonOpenTemp = GUICtrlCreateButton("Open %temp%", 280, 190, 150, 30)
GUICtrlSetFont(-1, 12, 400, 0, "Courier New")
GUICtrlSetState(-1, $GUI_DISABLE)
Local $idButtonExport = GUICtrlCreateButton("Export Data", 280, 230, 150, 30)
GUICtrlSetFont(-1, 12, 400, 0, "Courier New")
GUICtrlSetState(-1, $GUI_DISABLE)
Local $idButtonCopy = GUICtrlCreateButton("Copy Data", 440, 230, 150, 30)
GUICtrlSetFont(-1, 12, 400, 0, "Courier New")
GUICtrlSetState(-1, $GUI_DISABLE)
GUISetState(@SW_SHOW)

Global $hTimerStart = TimerInit()
$sOutputFileWithoutExtension &= "_" & $iTrackL & "+" & $iTrackR

ConsoleWrite("Layout: " & $iLayout & @CRLF)
Switch $iLayout
	Case $eMONO
		$sCommand = '-i "' & $sFile & '" -filter_complex "[0:' & $iTrackL - 1 + $iCounterVideo & '][0:' & $iTrackR - 1 + $iCounterVideo & '] amerge" -c:a pcm_s24le -ar 48000 -y "' & @TempDir & '\' & $sOutputFileWithoutExtension & '.wav"'
	Case $eSTEREO
		$sCommand = '-i "' & $sFile & '" -map 0:' & $iTrackR / 2 - 1 + $iCounterVideo & ' -c:a pcm_s24le -ar 48000 -y "' & @TempDir & '\' & $sOutputFileWithoutExtension & '.wav"'
	Case $eMULTI
		$sCommand = '-i "' & $sFile & '" -af "pan=stereo|c0=c' & $iTrackL - 1 + $iCounterVideo & '|c1=c' & $iTrackR - 1 + $iCounterVideo & '" -c:a pcm_s24le -ar 48000 -y "' & @TempDir & '\' & $sOutputFileWithoutExtension & '.wav"'
EndSwitch

ConsoleWrite("Command extract audio: " & $sCommand & @CRLF)
_runFFmpeg('ffmpeg ' & $sCommand, $sPathFFmpeg, 1)
GUICtrlSetData($Progress1, 100) ; if ffmpeg is done than set progress to 100 - sometimes last StderrRead with 100 is missed

If Not FileExists(@TempDir & '\' & $sOutputFileWithoutExtension & '.wav') Then ; error
	GUICtrlSetData($Edit, "Error: Could not extract audio.")
Else
	$sCommand = '-i "' & @TempDir & '\' & $sOutputFileWithoutExtension & '.wav" -filter_complex ebur128=framelog=verbose:peak=true -f null -'
	ConsoleWrite("Command measure audio: " & $sCommand & @CRLF)
	_runFFmpeg('ffmpeg ' & $sCommand, $sPathFFmpeg, 2)
	GUICtrlSetData($Progress2, 100) ; if ffmpeg is done than set progress to 100 - sometimes last StderrRead with 100 is missed

	GUICtrlSetData($Edit, _GetR128($g_sStdErrAll))
	GUICtrlSetState($idButtonOpenTemp, $GUI_ENABLE)
	GUICtrlSetState($idButtonExport, $GUI_ENABLE)
	GUICtrlSetState($idButtonCopy, $GUI_ENABLE)
EndIf
WinActivate("R128","")

While 1
	Switch GUIGetMsg()
		Case $GUI_EVENT_CLOSE
			ExitLoop
		Case $idButtonOpenTemp
			ShellExecute(@TempDir)
		Case $idButtonExport
			FileWrite(@TempDir & '\' & $sOutputFileWithoutExtension & '.txt', $sFile & @CRLF & @CRLF & GUICtrlRead($Edit) & @CRLF & @CRLF & "measurement time: " & StringRegExpReplace(GUICtrlRead($g_hLabelRunningTime), "\W", ""))
		Case $idButtonCopy
			ClipPut($sFile & @CRLF & @CRLF & GUICtrlRead($Edit) & @CRLF & @CRLF & "measurement time: " & StringRegExpReplace(GUICtrlRead($g_hLabelRunningTime), "\W", ""))
	EndSwitch
WEnd
Exit

Func _runFFmpeg($command, $wd, $iProgress)
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

Func _runFFprobe($command, $wd)
	Local $sStdErrAll
	Local $sStdErr
	Local $hPid = Run('"' & @ComSpec & '" /c ' & $command, $wd, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
	While 1
		Sleep(50)
		$sStdErr = StdoutRead($hPid)
		If @error Then ExitLoop
		$sStdErrAll &= $sStdErr
	WEnd
	$sStdErrAll = StringRegExpReplace($sStdErrAll, "\R$", "") ; delete last new line sequence
	Return $sStdErrAll
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

Func _StripFileExtension($sFile)
	Local $iDelimiter = StringInStr($sFile, ".", 0, -1)
	Return StringLeft($sFile, $iDelimiter - 1)
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

Func _TrackRadioPressed()
	Local $iTemp = @GUI_CtrlId
	$iTemp -= 2
	$iTemp *= 2
	$iTrackR = $iTemp
	$iTemp -= 1
	$iTrackL = $iTemp
	ConsoleWrite($iTemp & @CRLF)
EndFunc

Func _Exit()
	Exit
EndFunc

Func _ExitLoop()
	$g_bExitLoop = True
EndFunc
