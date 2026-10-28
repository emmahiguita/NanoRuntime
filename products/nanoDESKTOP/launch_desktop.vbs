' ==============================================================================
' ARCHIVO: launch_desktop.vbs
' QUÉ HACE: Lanzador silencioso de NanoAI Desktop para Windows.
' CÓMO FUNCIONA: Verifica si el puente HTTP local (puerto 3001) está activo.
'               Si no lo está, lo inicia en segundo plano sin ventana de consola,
'               y a continuación abre la ventana nativa de nanortime-desktop.exe.
' POR QUÉ: Permite al usuario iniciar la aplicación con un solo clic desde el
'          acceso directo del Escritorio sin dejar terminales negras abiertas.
' ==============================================================================

Set WshShell = CreateObject("WScript.Shell")
desktopDir = "c:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\products\nanoDESKTOP"
exePath = "c:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\target\debug\nanortime-desktop.exe"

WshShell.CurrentDirectory = desktopDir

' Iniciar start_lan.py si el puerto 3001 no está escuchando
checkCmd = "powershell -NoProfile -WindowStyle Hidden -Command ""if (-not (Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue)) { Start-Process python -ArgumentList '-B start_lan.py 3001' -WindowStyle Hidden -WorkingDirectory '" & desktopDir & "' }"""
WshShell.Run checkCmd, 0, True

' Iniciar la ventana nativa de escritorio
WshShell.Run """" & exePath & """", 1, False
