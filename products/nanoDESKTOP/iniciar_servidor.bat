@echo off
chcp 65001 >nul
:: ==============================================================================
:: ARCHIVO: iniciar_servidor.bat
:: QUÉ HACE: Arranca el servidor puente LAN de NanoAI Desktop en el puerto 3001.
:: CÓMO FUNCIONA: Ejecuta start_lan.py cargando la IP Wi-Fi y la clave fija.
:: POR QUÉ: Permite encender el servicio manualmente con un solo clic para conectar Nano Mobile.
:: ==============================================================================
title Servidor NanoAI LAN
cd /d "%~dp0"
python -B start_lan.py 3001
pause
