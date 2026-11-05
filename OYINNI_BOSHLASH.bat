@echo off
chcp 65001 >nul
title Global Strategiya
cd /d "%~dp0"
set "GD=%~dp0godot\Godot_v4.3-stable_win64.exe"
set "GDC=%~dp0godot\Godot_v4.3-stable_win64_console.exe"

if not exist "%GD%" (
  echo Godot dasturi yuklab olinmoqda, ~50 MB. Biroz kuting...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest -Uri 'https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip' -OutFile 'godot.zip'; Expand-Archive -Force 'godot.zip' 'godot'; Remove-Item 'godot.zip'; New-Item -ItemType File -Force 'godot\.gdignore' | Out-Null"
)
if not exist "%GD%" (
  echo XATO: Godot yuklab olinmadi. Internetni tekshiring.
  pause
  exit /b 1
)
echo Yangilanishlar tekshirilmoqda...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0yangilash.ps1"
echo Fayllar tayyorlanmoqda...
"%GDC%" --headless --path "%~dp0." --import >nul 2>&1
echo O'yin ochilmoqda...
start "" "%GD%" --path "%~dp0."
