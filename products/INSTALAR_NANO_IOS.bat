@echo off
TITLE Instalador Nano AI iOS
COLOR 0A
cls
echo ==========================================================
echo       NANO AI - INSTALADOR AUTOMATICO PARA iOS
echo ==========================================================
echo.
echo [1/3] Limpiando procesos previos de Sideloadly...
powershell -Command "(Get-WmiObject Win32_Process -Filter \"Name='sideloadly.exe' or Name='sideloadlydaemon.exe'\").Terminate()" >nul 2>&1
echo [OK] Procesos reiniciados.
echo.
echo [2/3] Verificando archivo NanoAI.ipa...
if not exist "%USERPROFILE%\Desktop\NanoAI.ipa" (
    if exist "%~dp0build_ios_artifacts\NanoAI.ipa" (
        copy /y "%~dp0build_ios_artifacts\NanoAI.ipa" "%USERPROFILE%\Desktop\NanoAI.ipa" >nul
    )
)
echo [OK] NanoAI.ipa listo en: %USERPROFILE%\Desktop\NanoAI.ipa
echo.
echo [3/3] Abriendo Sideloadly con Nano AI...
start "" "%LOCALAPPDATA%\Sideloadly\sideloadly.exe" "%USERPROFILE%\Desktop\NanoAI.ipa"
echo.
echo ==========================================================
echo  VENTANA DE SIDELOADLY ABIERTA:
echo  1. Verifica que tu iPhone aparezca seleccionado.
echo  2. Pulsa el boton START.
echo  3. En el iPhone: Ajustes -> General -> VPN y gestion -> Confiar.
echo ==========================================================
echo.
pause
