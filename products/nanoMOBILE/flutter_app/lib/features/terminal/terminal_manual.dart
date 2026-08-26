import 'terminal_types.dart';

/// Manual completo de uso y referencia de comandos para NanoTerminal.
///
/// Soporta consulta por categorías (`help <categoría>`) y páginas de manual
/// detalladas para cada comando (`man <comando>`).
class TerminalManual {
  const TerminalManual._();

  static const Map<String, List<String>> categories = {
    'sistema': [
      'help',
      'man',
      'clear',
      'date',
      'whoami',
      'uname',
      'hostname',
      'uptime',
      'id',
      'env',
      'export',
      'alias',
      'which',
      'type',
      'desktop',
      'sleep',
      'true',
      'false',
    ],
    'archivos': [
      'ls',
      'cd',
      'pwd',
      'mkdir',
      'touch',
      'cp',
      'mv',
      'rm',
      'cat',
      'head',
      'tail',
      'grep',
      'find',
      'tree',
      'diff',
      'wc',
      'source',
      'chmod',
      'stat',
      'basename',
      'dirname',
    ],
    'ia': ['ai', 'infer', 'tune', 'gpu', 'nvtop'],
    'devops': [
      'docker',
      'kali',
      'crontab',
      'watch',
      'script',
      'plugin',
      'bootstrap',
    ],
    'red': [
      'wifi',
      'battery',
      'weather',
      'ping',
      'curl',
      'wget',
      'share',
      'sshd',
    ],
    'monitor': ['free', 'df', 'top', 'ps', 'kill', 'dmesg', 'vmstat', 'iotop'],
    'paquetes': ['pkg', 'apt', 'pip', 'npm', 'cargo', 'gem'],
    'terminal': ['pty', 'bash', 'toybox', 'vim', 'nano', 'python', 'htop'],
  };

  static const Map<String, ({String desc, String usage, String example})>
  _manualPages = {
    // ── Sistema ──
    'help': (
      desc: 'Muestra el índice general de comandos o la guía de una categoría.',
      usage: 'help [categoría]',
      example: 'help ia  |  help devops  |  help archivos',
    ),
    'man': (
      desc:
          'Muestra la página de manual detallada con sintaxis y ejemplos de un comando.',
      usage: 'man <comando>',
      example: 'man ai  |  man docker  |  man grep  |  man kali',
    ),
    'clear': (
      desc: 'Limpia todas las líneas del buffer visual de la terminal.',
      usage: 'clear',
      example: 'clear',
    ),
    'date': (
      desc:
          'Muestra la fecha y hora actual del sistema en formato local o UTC.',
      usage: 'date [--utc]',
      example: 'date  |  date --utc',
    ),
    'whoami': (
      desc:
          'Muestra el nombre del usuario o UID real de Android que ejecuta la app.',
      usage: 'whoami',
      example: 'whoami',
    ),
    'uname': (
      desc:
          'Imprime información del kernel Linux, arquitectura de CPU y release del SO.',
      usage: 'uname [-a | -r | -m | -n]',
      example: 'uname -a  |  uname -m',
    ),
    'hostname': (
      desc: 'Muestra el nombre de host configurado en el dispositivo.',
      usage: 'hostname',
      example: 'hostname',
    ),
    'uptime': (
      desc:
          'Indica el tiempo que el dispositivo lleva encendido de forma continua.',
      usage: 'uptime',
      example: 'uptime',
    ),
    'id': (
      desc:
          'Muestra el UID, GID y los grupos suplementarios reales asignados al proceso.',
      usage: 'id',
      example: 'id',
    ),
    'env': (
      desc:
          'Lista todas las variables de entorno o muestra el valor de una en específico.',
      usage: 'env [variable]',
      example: 'env  |  env PATH  |  env HOME',
    ),
    'export': (
      desc: 'Define o actualiza una variable de entorno para la sesión actual.',
      usage: 'export CLAVE=VALOR',
      example: 'export MI_VAR=123  |  export PATH=/usr/bin:\$PATH',
    ),
    'alias': (
      desc: 'Crea o visualiza atajos rápidos de comandos en la terminal.',
      usage: 'alias [nombre=comando]',
      example: 'alias  |  alias ll="ls -la"',
    ),
    'which': (
      desc: 'Localiza la ruta del binario ejecutable en el PATH.',
      usage: 'which <comando>',
      example: 'which bash  |  which python',
    ),
    'type': (
      desc:
          'Describe cómo se interpretaría un nombre de comando (alias, built-in o binario).',
      usage: 'type <comando>',
      example: 'type ls  |  type ll',
    ),
    'desktop': (
      desc: 'Navega a la pantalla del entorno de escritorio gráfico X11/VNC.',
      usage: 'desktop',
      example: 'desktop',
    ),
    'sleep': (
      desc: 'Pausa la ejecución durante el número de segundos especificado.',
      usage: 'sleep <segundos>',
      example: 'sleep 2',
    ),

    // ── Archivos ──
    'ls': (
      desc:
          'Lista los archivos y subdirectorios del directorio actual o especificado.',
      usage: 'ls [-l | -a | -la | -lh | -R] [ruta]',
      example: 'ls  |  ls -la  |  ls /home/nanoai',
    ),
    'cd': (
      desc: 'Cambia el directorio de trabajo actual.',
      usage: 'cd [ruta | .. | ~]',
      example: 'cd ..  |  cd /home  |  cd subcarpeta',
    ),
    'pwd': (
      desc: 'Imprime la ruta absoluta del directorio de trabajo actual.',
      usage: 'pwd',
      example: 'pwd',
    ),
    'mkdir': (
      desc: 'Crea uno o varios directorios en el almacenamiento.',
      usage: 'mkdir [-p] <directorio>',
      example: 'mkdir mis_archivos  |  mkdir -p proyectos/nano/src',
    ),
    'touch': (
      desc:
          'Crea un archivo vacío o actualiza la fecha de modificación de uno existente.',
      usage: 'touch <archivo>',
      example: 'touch notas.txt  |  touch script.py',
    ),
    'cp': (
      desc: 'Copia archivos o directorios de origen a destino.',
      usage: 'cp <origen> <destino>',
      example: 'cp config.json config.backup.json',
    ),
    'mv': (
      desc: 'Mueve o renombra un archivo o directorio.',
      usage: 'mv <origen> <destino>',
      example: 'mv viejo.txt nuevo.txt  |  mv data.csv /home/nanoai/',
    ),
    'rm': (
      desc: 'Elimina archivos o árboles de directorios.',
      usage: 'rm [-r | -f | -rf] <archivo/carpeta>',
      example: 'rm temp.log  |  rm -r carpeta_vieja',
    ),
    'cat': (
      desc:
          'Lee y muestra el contenido completo de uno o más archivos de texto.',
      usage: 'cat <archivo>',
      example: 'cat README.md  |  cat /proc/cpuinfo',
    ),
    'head': (
      desc: 'Imprime las primeras N líneas de un archivo (10 por defecto).',
      usage: 'head [-n líneas] <archivo>',
      example: 'head -n 5 log.txt',
    ),
    'tail': (
      desc: 'Imprime las últimas N líneas de un archivo (10 por defecto).',
      usage: 'tail [-n líneas] <archivo>',
      example: 'tail -n 20 error.log',
    ),
    'grep': (
      desc:
          'Busca patrones de texto o expresiones regulares dentro de archivos.',
      usage: 'grep [-i] [-n] [-v] <patrón> <archivo>',
      example: 'grep ERROR log.txt  |  grep -i "token" main.dart',
    ),
    'find': (
      desc:
          'Busca archivos y carpetas de forma recursiva en el árbol de directorios.',
      usage: 'find [ruta] [-name patrón]',
      example: 'find .  |  find /home -name "*.py"',
    ),
    'tree': (
      desc:
          'Muestra una representación visual en árbol jerárquico de carpetas.',
      usage: 'tree [directorio]',
      example: 'tree  |  tree /home/nanoai',
    ),
    'diff': (
      desc: 'Compara dos archivos línea por línea y muestra las divergencias.',
      usage: 'diff <archivo1> <archivo2>',
      example: 'diff version1.txt version2.txt',
    ),
    'wc': (
      desc: 'Cuenta líneas (-l), palabras (-w) o bytes (-c) de un archivo.',
      usage: 'wc [-l | -w | -c] <archivo>',
      example: 'wc -l dataset.csv',
    ),
    'source': (
      desc:
          'Lee y ejecuta comandos secuencialmente desde un archivo de script.',
      usage: 'source <archivo.sh>',
      example: 'source setup.sh',
    ),
    'chmod': (
      desc:
          'Cambia los permisos de lectura, escritura y ejecución de un archivo.',
      usage: 'chmod <permisos> <archivo>',
      example: 'chmod +x run.sh  |  chmod 755 binary',
    ),
    'stat': (
      desc:
          'Muestra el estado detallado de un archivo o del sistema NanoRuntime.',
      usage: 'stat [--all | --memory | --cpu] [archivo]',
      example: 'stat --all  |  stat notas.txt',
    ),

    // ── Inteligencia Artificial ──
    'ai': (
      desc: 'Consulta al motor LLM local mediante prompt en lenguaje natural.',
      usage: 'ai <pregunta o instrucción>',
      example: 'ai ¿cómo crear un socket en C?  |  ai explica qué es un kernel',
    ),
    'infer': (
      desc:
          'Ejecuta inferencia directa midiendo latencia en milisegundos y velocidad en tokens/s.',
      usage: 'infer <prompt>',
      example: 'infer "Resume en tres viñetas las leyes de la termodinámica"',
    ),
    'tune': (
      desc:
          'Diagnóstico integral de hardware (RAM, cores, temperatura) y benchmark TPS con sugerencias de optimización.',
      usage: 'tune',
      example: 'tune',
    ),
    'gpu': (
      desc:
          'Inspecciona el chip gráfico GPU, frecuencia actual, temperatura y carga de trabajo.',
      usage: 'gpu',
      example: 'gpu',
    ),
    'nvtop': (
      desc: 'Monitor visual de estado de GPU en tiempo real.',
      usage: 'nvtop',
      example: 'nvtop',
    ),

    // ── DevOps & Contenedores ──
    'docker': (
      desc: 'Gestor de contenedores aislados ARM64 mediante PRoot.',
      usage: 'docker [pull | run | ps | images | stop | rm] [args...]',
      example: 'docker pull alpine  |  docker run alpine echo "hola"',
    ),
    'kali': (
      desc:
          'Entorno Kali Linux ARM64 completo con suite de herramientas de seguridad.',
      usage: 'kali [install | shell | run <cmd> | audit]',
      example: 'kali install  |  kali shell  |  kali run nmap -sV 192.168.1.1',
    ),
    'crontab': (
      desc: 'Programa tareas periódicas en segundo plano dentro de la sesión.',
      usage: 'crontab [list | add <min> <cmd> | remove <id> | clear]',
      example: 'crontab add 5 "stat --all"  |  crontab list',
    ),
    'watch': (
      desc:
          'Ejecuta un comando repetidamente a intervalos regulares mostrando la salida.',
      usage: 'watch <segundos> <comando>',
      example: 'watch 2 "free"  |  watch 5 "gpu"',
    ),
    'bootstrap': (
      desc: 'Descarga e inicializa el rootfs Termux completo (~30 MB).',
      usage: 'bootstrap',
      example: 'bootstrap',
    ),

    // ── Red & Hardware ──
    'wifi': (
      desc:
          'Consulta estado de la conexión WiFi, SSID, intensidad de señal dBm e IP.',
      usage: 'wifi',
      example: 'wifi',
    ),
    'battery': (
      desc:
          'Lee el nivel porcentual, temperatura y estado de carga de la batería del kernel.',
      usage: 'battery',
      example: 'battery',
    ),
    'weather': (
      desc:
          'Consulta el pronóstico meteorológico en vivo para tu ubicación o ciudad.',
      usage: 'weather [ciudad]',
      example: 'weather  |  weather Madrid  |  weather Tokyo',
    ),
    'ping': (
      desc:
          'Verifica conectividad y latencia hacia una dirección IP o dominio.',
      usage: 'ping <host>',
      example: 'ping 8.8.8.8  |  ping google.com',
    ),
    'curl': (
      desc: 'Realiza peticiones HTTP y muestra el contenido recibido.',
      usage: 'curl [-s] <url>',
      example: 'curl https://httpbin.org/ip',
    ),
    'wget': (
      desc: 'Descarga archivos desde una URL web hacia el disco.',
      usage: 'wget <url>',
      example: 'wget https://ejemplo.com/archivo.zip',
    ),
    'share': (
      desc:
          'Inicia un servidor HTTP local en el puerto indicado para compartir archivos.',
      usage: 'share [puerto]',
      example: 'share 8080',
    ),
    'sshd': (
      desc: 'Controla el servidor de acceso seguro SSH en el puerto 8022.',
      usage: 'sshd [start]',
      example: 'sshd  |  sshd start',
    ),

    // ── Monitor del Sistema ──
    'free': (
      desc:
          'Muestra la memoria RAM total, usada, libre y buffers/caché reales.',
      usage: 'free [-m | -g | -h]',
      example: 'free  |  free -m',
    ),
    'df': (
      desc:
          'Muestra el espacio total, usado y disponible en los sistemas de archivos montados.',
      usage: 'df [-h]',
      example: 'df -h',
    ),
    'top': (
      desc: 'Muestra los procesos en ejecución y consumo de recursos.',
      usage: 'top',
      example: 'top',
    ),
    'ps': (
      desc: 'Lista los procesos del sistema con su PID, usuario y comando.',
      usage: 'ps [aux]',
      example: 'ps  |  ps aux',
    ),
    'kill': (
      desc: 'Envía una señal de terminación a un proceso por su PID.',
      usage: 'kill [-9] <pid>',
      example: 'kill 1234  |  kill -9 1234',
    ),
    'dmesg': (
      desc: 'Muestra los mensajes del buffer circular del kernel Linux.',
      usage: 'dmesg',
      example: 'dmesg',
    ),

    // ── Paquetes & Lenguajes ──
    'pkg': (
      desc:
          'Gestor de paquetes de Termux para instalar herramientas y bibliotecas.',
      usage: 'pkg [install | update | upgrade | search | remove] <paquete>',
      example: 'pkg update  |  pkg install git  |  pkg install nodejs',
    ),
    'apt': (
      desc: 'Interfaz APT para gestión de paquetes debian en el rootfs.',
      usage: 'apt [update | install | remove] <paquete>',
      example: 'apt update  |  apt install python',
    ),
    'pip': (
      desc: 'Gestor de paquetes de Python en el rootfs.',
      usage: 'pip [install | list | uninstall] <paquete>',
      example: 'pip install numpy  |  pip list',
    ),
    'npm': (
      desc: 'Gestor de paquetes de Node.js en el rootfs.',
      usage: 'npm [install | run] <paquete>',
      example: 'npm install express',
    ),

    // ── Terminal Interactiva ──
    'pty': (
      desc:
          'Abre una sesión interactiva en un pseudo-terminal real con emulación ANSI VT100.',
      usage: 'pty [binario]',
      example: 'pty bash  |  pty python  |  pty htop',
    ),
    'bash': (
      desc: 'Ejecuta el shell GNU Bash en modo interactivo o script.',
      usage: 'bash [-c "comando"]',
      example: 'bash  |  bash -c "echo hola"',
    ),
    'toybox': (
      desc: 'Invoca utilidades directas de Toybox.',
      usage: 'toybox [utilidad] [args...]',
      example: 'toybox uname -a',
    ),
    'vim': (
      desc: 'Editor de texto visual interactivo (requiere sesión PTY).',
      usage: 'vim <archivo>',
      example: 'pty vim notas.txt',
    ),
    'nano': (
      desc: 'Editor de texto sencillo para terminal (requiere sesión PTY).',
      usage: 'nano <archivo>',
      example: 'pty nano config.ini',
    ),
    'python': (
      desc: 'Inicia el intérprete interactivo REPL de Python.',
      usage: 'python [script.py]',
      example: 'pty python',
    ),
  };

  /// Renderiza el índice general o la categoría solicitada por `help`.
  static void printHelp(List<String> args, void Function(String, Ln) out) {
    if (args.isEmpty) {
      out('═══ MANUAL Y REFERENCIA DE NANO TERMINAL ═══', Ln.header);
      out('Usa "help <categoría>" para ver los comandos de un grupo:', Ln.info);
      for (final entry in categories.entries) {
        final catTitle = entry.key.toUpperCase();
        out('  ▸ $catTitle: ${entry.value.join(", ")}', Ln.stdout);
      }
      out('', Ln.stdout);
      out('Comandos destacados:', Ln.header);
      out('  ai <pregunta>    → Consultar al modelo LLM local', Ln.info);
      out('  tune             → Benchmark TPS y optimización de RAM', Ln.info);
      out('  kali shell       → Abrir terminal Kali Linux ARM64', Ln.info);
      out('  docker run       → Ejecutar contenedores aislados', Ln.info);
      out(
        '  man <comando>    → Ver manual detallado con sintaxis y ejemplos',
        Ln.info,
      );
      out(
        '  ! <comando>      → Ejecutar en ash con BusyBox real (ej: !ls -la)',
        Ln.info,
      );
      return;
    }

    final query = args.first.toLowerCase();
    final group = categories[query];
    if (group != null) {
      out('═══ CATEGORÍA: ${query.toUpperCase()} ═══', Ln.header);
      for (final cmd in group) {
        final page = _manualPages[cmd];
        if (page != null) {
          out('• $cmd', Ln.success);
          out('  ${page.desc}', Ln.stdout);
          out('  Uso: ${page.usage}', Ln.info);
          out('  Ejemplo: ${page.example}', Ln.system);
        } else {
          out('• $cmd', Ln.stdout);
        }
      }
      return;
    }

    // Si el usuario escribió `help <comando>`, redirigir a `man <comando>`
    printMan([query], out);
  }

  /// Renderiza la página de manual específica para un comando (`man <cmd>`).
  static void printMan(List<String> args, void Function(String, Ln) out) {
    if (args.isEmpty) {
      out(
        'man: especifica el comando a consultar. Ej: "man ai", "man docker"',
        Ln.stderr,
      );
      return;
    }

    final cmd = args.first.toLowerCase();
    final page = _manualPages[cmd];
    if (page == null) {
      out(
        'man: no hay manual específico para "$cmd". Usa "help" para ver la lista.',
        Ln.stderr,
      );
      return;
    }

    out(
      '╔═══════════════════════════════════════════════════════════════╗',
      Ln.header,
    );
    out('  MANUAL DE COMANDO: ${cmd.toUpperCase()}', Ln.header);
    out(
      '╚═══════════════════════════════════════════════════════════════╝',
      Ln.header,
    );
    out('DESCRIPCIÓN:', Ln.info);
    out('  ${page.desc}', Ln.stdout);
    out('', Ln.stdout);
    out('SINTAXIS:', Ln.info);
    out('  ${page.usage}', Ln.success);
    out('', Ln.stdout);
    out('EJEMPLOS DE USO:', Ln.info);
    out('  ${page.example}', Ln.system);
  }
}
