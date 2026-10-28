"""
MÓDULO: create_shortcut.py
QUÉ HACE: Crea o actualiza el acceso directo 'NanoAI Desktop' en el Escritorio de Windows.
CÓMO FUNCIONA: Utiliza WScript.Shell de Windows para asociar el icono oficial del búho y el lanzador.
POR QUÉ: Permite instalar/anclar la aplicación directamente en el PC del usuario.
"""
import os
import subprocess
from pathlib import Path

desktop = Path(os.environ["USERPROFILE"]) / "Desktop"
lnk = desktop / "NanoAI Desktop.lnk"
vbs = Path(r"c:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\products\nanoDESKTOP\launch_desktop.vbs")
icon = Path(r"c:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\products\nanoDESKTOP\src-tauri\icons\icon.ico")
workdir = Path(r"c:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\products\nanoDESKTOP")

ps_script = f"""
$w = New-Object -ComObject WScript.Shell
$s = $w.CreateShortcut('{lnk}')
$s.TargetPath = 'wscript.exe'
$s.Arguments = '"{vbs}"'
$s.WorkingDirectory = '{workdir}'
$s.IconLocation = '{icon},0'
$s.Description = 'NanoAI Studio Desktop'
$s.Save()
"""

subprocess.run(["powershell", "-NoProfile", "-Command", ps_script], check=True)
print(f"Acceso directo creado correctamente en: {lnk}")
