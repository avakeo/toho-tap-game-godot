@echo off
rem 会話CSVの検証を実行する。GODOT_PATH環境変数があればそれを使う。
set GODOT=%GODOT_PATH%
if "%GODOT%"=="" set GODOT=C:\Users\naoko\Downloads\AppSetup\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe
"%GODOT%" --headless --path "%~dp0.." -s tools/validate_dialogues.gd
pause
