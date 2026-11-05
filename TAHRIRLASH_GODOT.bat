@echo off
cd /d "%~dp0"
if not exist "%~dp0godot\Godot_v4.3-stable_win64.exe" (
  echo Avval OYINNI_BOSHLASH.bat ni ishga tushiring.
  pause
  exit /b 1
)
start "" "%~dp0godot\Godot_v4.3-stable_win64.exe" -e --path "%~dp0."
