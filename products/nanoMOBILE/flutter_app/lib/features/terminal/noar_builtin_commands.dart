const List<Map<String, dynamic>> noarBuiltinCommands = [
  {
    'cmd': 'bootstrap',
    'desc': 'Instalar rootfs Termux (~30 MB). Requiere WiFi.',
    'tag': 'rootfs',
  },
  {
    'cmd': '!ls -la /usr/bin | head -20',
    'desc': 'Listar binarios reales del rootfs Termux (bash, apt, python...)',
    'tag': 'shell',
  },
  {
    'cmd': '!apt update && apt install python',
    'desc': 'Actualizar índice de paquetes e instalar Python real en Termux.',
    'tag': 'pkgs',
  },
  {
    'cmd': '!pip install numpy torch',
    'desc': 'Instalar NumPy y PyTorch en el Python real del rootfs.',
    'tag': 'pkgs',
  },
  {
    'cmd': 'kali install',
    'desc': 'Descargar Kali Linux ARM64 (~200 MB). Requiere WiFi y proot.',
    'tag': 'kali',
  },
  {
    'cmd': 'kali shell',
    'desc': 'Abrir shell bash dentro de Kali Linux (vía proot).',
    'tag': 'kali',
  },
  {
    'cmd': 'kali run nmap -sV 192.168.1.1',
    'desc': 'Ejecutar nmap dentro de Kali (requiere Kali instalado).',
    'tag': 'kali',
  },
  {
    'cmd': 'docker pull alpine',
    'desc': 'Descargar imagen Alpine Linux ARM64 desde Docker Hub.',
    'tag': 'containers',
  },
  {
    'cmd': 'docker run alpine echo "hola desde contenedor"',
    'desc': 'Ejecutar un comando dentro de un contenedor Alpine (vía proot).',
    'tag': 'containers',
  },
  {
    'cmd': 'docker ps',
    'desc': 'Listar contenedores activos.',
    'tag': 'containers',
  },
  {
    'cmd': '!ps aux',
    'desc': 'Listar todos los procesos del sistema (vía toybox real).',
    'tag': 'monitor',
  },
  {
    'cmd': 'free',
    'desc': 'Mostrar memoria RAM disponible (datos reales de /proc/meminfo).',
    'tag': 'monitor',
  },
  {
    'cmd': 'df',
    'desc': 'Mostrar espacio en disco (datos reales de StatFs).',
    'tag': 'monitor',
  },
  {
    'cmd': 'uname -a',
    'desc': 'Info del kernel Android y arquitectura (aarch64).',
    'tag': 'monitor',
  },
  {
    'cmd': 'status',
    'desc': 'Diagnóstico completo: shell, rootfs, proot, kali, docker, device.',
    'tag': 'general',
  },
  {
    'cmd': '!git clone https://github.com/user/repo',
    'desc': 'Clonar repositorio Git (requiere git instalado en Termux).',
    'tag': 'remote',
  },
  {
    'cmd': '!curl -L https://example.com',
    'desc': 'Descargar contenido web (requiere curl instalado en Termux).',
    'tag': 'remote',
  },
  {
    'cmd': 'ai ¿cómo optimizar el uso de RAM en Android?',
    'desc': 'Consultar al motor LLM local sobre optimización de memoria.',
    'tag': 'ai',
  },
  {
    'cmd': 'infer "explícame qué es proot y cómo funciona"',
    'desc': 'Inferencia directa en el motor LLM (llama.cpp en localhost:8080).',
    'tag': 'ai',
  },
  {
    'cmd': '!find /usr -name "*.so" | head -10',
    'desc': 'Buscar librerías .so en el rootfs Termux.',
    'tag': 'shell',
  },
  {
    'cmd': '!tar -czf backup.tar.gz /usr/share',
    'desc': 'Crear backup comprimido del rootfs.',
    'tag': 'shell',
  },
  {
    'cmd': '!python3 -c "import torch; print(torch.cuda.is_available())"',
    'desc': 'Verificar si PyTorch detecta GPU (requiere torch instalado).',
    'tag': 'ai',
  },
  {
    'cmd': '!nmap -sP 192.168.0.0/24',
    'desc': 'Escanear red local con nmap (dentro de Kali).',
    'tag': 'kali',
  },
  {
    'cmd': 'ls -la ~',
    'desc': 'Listar el home real del rootfs Termux (archivos reales en disco).',
    'tag': 'fs',
  },
  {
    'cmd': 'cat ~/.bashrc',
    'desc': 'Ver la configuración real del shell bash del rootfs.',
    'tag': 'fs',
  },
];
