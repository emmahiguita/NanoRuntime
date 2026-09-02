/// Comandos precargados de la Noar Library.
///
/// REGLA DE REALIDAD (TER-10): cada comando aquí existe y ejecuta en el
/// bash real del rootfs. Verificados contra files/nano/usr/bin del device
/// (636 binarios, run-as dev.nanoai.mobile). Sin prefijos "!" (sintaxis del
/// dispatcher Dart, no de bash), sin builtins Dart (status/ai/infer/kali/
/// docker/bootstrap viven en el dispatcher, no en el bash), sin binarios
/// ausentes (pip, nmap, torch no están en el rootfs — honestidad).
///
/// Los pipes/redirecciones son válidos: el bash real los maneja nativo.
const List<Map<String, dynamic>> noarBuiltinCommands = [
  // ── FS ──
  {
    'cmd': 'ls -la ~',
    'desc': 'Listar el home real del rootfs (archivos reales en disco).',
    'tag': 'fs',
  },
  {
    'cmd': 'cat ~/.bashrc',
    'desc': 'Ver la configuración real del shell bash del rootfs.',
    'tag': 'fs',
  },
  {
    'cmd': 'du -sh /usr',
    'desc': 'Tamaño real del rootfs Termux en disco.',
    'tag': 'fs',
  },
  {
    'cmd': 'find /usr -name "*.so" | head -10',
    'desc': 'Buscar librerías .so en el rootfs.',
    'tag': 'fs',
  },
  {
    'cmd': 'file /usr/bin/bash',
    'desc': 'Tipo del binario bash real (ELF arm64, estático/dinámico).',
    'tag': 'fs',
  },

  // ── Shell ──
  {
    'cmd': 'ls /usr/bin | wc -l',
    'desc': 'Contar los binarios reales instalados en el rootfs.',
    'tag': 'shell',
  },
  {
    'cmd': 'which python3',
    'desc': 'Ruta real del intérprete python3 en el rootfs.',
    'tag': 'shell',
  },
  {
    'cmd': 'echo \$PATH',
    'desc': 'Ver el PATH que usa el bash real.',
    'tag': 'shell',
  },
  {
    'cmd': 'date',
    'desc': 'Fecha y hora del sistema.',
    'tag': 'shell',
  },
  {
    'cmd': 'clear',
    'desc': 'Limpiar la pantalla del terminal.',
    'tag': 'shell',
  },

  // ── Pkgs (apt real del rootfs, requiere WiFi) ──
  {
    'cmd': 'apt update',
    'desc': 'Actualizar el índice de paquetes del rootfs. Requiere WiFi.',
    'tag': 'pkgs',
  },
  {
    'cmd': 'apt list --installed | head -20',
    'desc': 'Ver los primeros paquetes instalados en el rootfs.',
    'tag': 'pkgs',
  },
  {
    'cmd': 'apt install <paquete>',
    'desc': 'Instalar un paquete real en el rootfs (ej.: apt install python).',
    'tag': 'pkgs',
  },
  {
    'cmd': 'dpkg -l | head -20',
    'desc': 'Listar paquetes dpkg instalados.',
    'tag': 'pkgs',
  },

  // ── Monitor ──
  {
    'cmd': 'ps aux',
    'desc': 'Listar todos los procesos del sistema.',
    'tag': 'monitor',
  },
  {
    'cmd': 'free',
    'desc': 'Mostrar memoria RAM disponible (datos reales de /proc/meminfo).',
    'tag': 'monitor',
  },
  {
    'cmd': 'df -h',
    'desc': 'Mostrar espacio en disco de todos los filesystems.',
    'tag': 'monitor',
  },
  {
    'cmd': 'top',
    'desc': 'Procesos en tiempo real (interactivo; salir con q).',
    'tag': 'monitor',
  },
  {
    'cmd': 'htop',
    'desc': 'Monitor interactivo con colores (salir con F10).',
    'tag': 'monitor',
  },
  {
    'cmd': 'uname -a',
    'desc': 'Info del kernel Android y arquitectura (aarch64).',
    'tag': 'monitor',
  },

  // ── Remote (binarios reales del rootfs) ──
  {
    'cmd': 'curl -L https://example.com',
    'desc': 'Descargar contenido web (curl real del rootfs).',
    'tag': 'remote',
  },
  {
    'cmd': 'wget https://example.com',
    'desc': 'Descargar contenido web (wget real del rootfs).',
    'tag': 'remote',
  },
  {
    'cmd': 'git clone https://github.com/user/repo',
    'desc': 'Clonar repositorio (git real del rootfs).',
    'tag': 'remote',
  },
  {
    'cmd': 'termux-info',
    'desc': 'Información del entorno Termux del rootfs.',
    'tag': 'remote',
  },

  // ── IA local (python3 real) ──
  {
    'cmd': 'python3 -c "print(\'hola desde python real\')"',
    'desc': 'Verificar el intérprete python3 real del rootfs.',
    'tag': 'ai',
  },
  {
    'cmd': 'python3 -m http.server 8080',
    'desc': 'Servir el directorio actual por HTTP (python real; Ctrl+C para salir).',
    'tag': 'ai',
  },

  // ── General ──
  {
    'cmd': 'nano ~/nota.txt',
    'desc': 'Abrir el editor real nano en el home (Ctrl+X para salir).',
    'tag': 'general',
  },
  {
    'cmd': 'tar -czf ~/backup.tar.gz /usr/share',
    'desc': 'Crear backup comprimido real del rootfs.',
    'tag': 'general',
  },
];
