@echo off
REM ==============================================================================
REM NanoAI — Lanzador rápido de instalación iOS desde Windows
REM ==============================================================================
TITLE Instalador NanoAI iOS
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_ios.ps1"
pause
