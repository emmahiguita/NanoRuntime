@echo off
chcp 65001 >nul
:: ==============================================================================
:: ARCHIVO: detener_servidor.bat
:: QUÉ HACE: Detiene por completo el servidor puente y el motor de modelos en RAM.
:: CÓMO FUNCIONA: Localiza y finaliza cualquier proceso en el puerto 3001 y nanortime-web.exe.
:: POR QUÉ: Permite apagar el servicio y liberar el 100% de la memoria RAM con 1 clic.
:: ==============================================================================
echo Deteniendo servidor NanoAI y liberando memoria RAM...
powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }"
taskkill /F /IM nanortime-web.exe >nul 2>&1
echo.
echo [OK] Servidor detenido y memoria RAM liberada.
timeout /t 3 >nul
