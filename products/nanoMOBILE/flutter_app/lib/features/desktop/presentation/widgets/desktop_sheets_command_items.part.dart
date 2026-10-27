part of 'desktop_sheets.dart';

const List<_CommandItem> _commands = [
  // 🛡️ Ciberseguridad & Kali
  _CommandItem(
    title: 'Escaneo de Puertos y Servicios',
    category: 'Ciberseguridad',
    command: 'nmap -sV -F 127.0.0.1',
    description:
        'Audita y detecta qué servicios y versiones están escuchando en la red local mediante un escaneo rápido con Nmap.',
    icon: Icons.shield_rounded,
  ),
  _CommandItem(
    title: 'Captura de Paquetes en Vivo',
    category: 'Ciberseguridad',
    command: 'tcpdump -i any -c 10',
    description:
        'Captura e inspecciona en tiempo real los primeros 10 paquetes de tráfico de red en todas las interfaces activas.',
    icon: Icons.network_check_rounded,
  ),
  _CommandItem(
    title: 'Auditoría de Puertos y Procesos',
    category: 'Ciberseguridad',
    command: 'netstat -tulpn',
    description:
        'Muestra todas las conexiones de red abiertas, sockets TCP/UDP y los nombres/PIDs de procesos asociados.',
    icon: Icons.lan_rounded,
  ),
  _CommandItem(
    title: 'Consulta WHOIS e IP Pública',
    category: 'Ciberseguridad',
    command: 'whois 8.8.8.8',
    description:
        'Obtiene información de propiedad, ASN, proveedor de servicios y rango asignado para una dirección IP o dominio.',
    icon: Icons.travel_explore_rounded,
  ),
  _CommandItem(
    title: 'Monitoreo de Interfaces Tshark',
    category: 'Ciberseguridad',
    command: 'tshark -D',
    description:
        'Muestra todas las interfaces de red disponibles para análisis de tráfico profundo con Wireshark/Tshark.',
    icon: Icons.manage_search_rounded,
  ),
  _CommandItem(
    title: 'Rastreo de Ruta ICMP',
    category: 'Ciberseguridad',
    command: 'traceroute 1.1.1.1',
    description: 'Mapea la ruta completa de saltos de red y evalúa latencias en cada router hasta la IP destino.',
    icon: Icons.alt_route_rounded,
  ),
  _CommandItem(
    title: 'Prueba de Conectividad Latencia',
    category: 'Ciberseguridad',
    command: 'ping -c 4 1.1.1.1',
    description:
        'Envía 4 paquetes ICMP de prueba a Cloudflare DNS para verificar conectividad y medir tiempos de respuesta en milisegundos.',
    icon: Icons.speed_rounded,
  ),
  _CommandItem(
    title: 'Ayuda de Hydra (Brute-force)',
    category: 'Ciberseguridad',
    command: 'hydra -h',
    description:
        'Muestra las opciones de configuración y uso de la herramienta de pruebas de autenticación y auditoría de claves Hydra.',
    icon: Icons.lock_open_rounded,
  ),
  _CommandItem(
    title: 'Ayuda de Sqlmap (Inyección SQL)',
    category: 'Ciberseguridad',
    command: 'sqlmap -h',
    description:
        'Muestra el menú de comandos de Sqlmap para detección y verificación de vulnerabilidades de inyección SQL en aplicaciones.',
    icon: Icons.bug_report_rounded,
  ),

  // 📊 Monitoreo & Diagnóstico
  _CommandItem(
    title: 'Monitor Interactivo Htop',
    category: 'Monitoreo',
    command: 'htop',
    description:
        'Despliega la consola gráfica interactiva en tiempo real para visualizar uso de CPU, RAM, Swap y administrar procesos.',
    icon: Icons.bar_chart_rounded,
  ),
  _CommandItem(
    title: 'Diagnóstico Nano Linux',
    category: 'Monitoreo',
    command: 'nano-info',
    description:
        'Muestra el reporte oficial de arquitectura, versión de kernel, hilos de CPU, RAM libre y estado de la sesión Nano Linux.',
    icon: Icons.laptop_chromebook_rounded,
  ),
  _CommandItem(
    title: 'Uso de Memoria RAM',
    category: 'Monitoreo',
    command: 'free -h',
    description:
        'Presenta el resumen legible en MB/GB de memoria RAM total, usada, libre, compartida, buffers y memoria disponible.',
    icon: Icons.memory_rounded,
  ),
  _CommandItem(
    title: 'Almacenamiento en Disco',
    category: 'Monitoreo',
    command: 'df -h',
    description: 'Calcula el espacio utilizado y disponible en todos los sistemas de archivos montados en Nano Linux.',
    icon: Icons.storage_rounded,
  ),
  _CommandItem(
    title: 'Top Procesos por CPU',
    category: 'Monitoreo',
    command: 'ps aux --sort=-%cpu | head -n 10',
    description: 'Filtra y muestra los 10 procesos con mayor consumo de recursos de procesamiento en el sistema.',
    icon: Icons.developer_board_rounded,
  ),
  _CommandItem(
    title: 'Top Procesos por RAM',
    category: 'Monitoreo',
    command: 'ps aux --sort=-%mem | head -n 10',
    description: 'Filtra y lista los 10 procesos que están consumiendo mayor cantidad de memoria RAM.',
    icon: Icons.pie_chart_rounded,
  ),
  _CommandItem(
    title: 'Tiempo de Actividad y Carga',
    category: 'Monitoreo',
    command: 'uptime',
    description:
        'Informa el tiempo exacto que lleva encendida la sesión Linux y los promedios de carga a 1, 5 y 15 minutos.',
    icon: Icons.timer_rounded,
  ),

  // 📦 Instalar Herramientas Kali / Pentest
  _CommandItem(
    title: 'Instalar Suite Red (Nmap & Tcpdump)',
    category: 'Instalación',
    command: 'pkg install -y nmap tshark tcpdump netcat-openbsd',
    description:
        'Instala en Nano Linux el conjunto esencial de herramientas para análisis de paquetes, trazado de rutas y auditoría de puertos.',
    icon: Icons.download_for_offline_rounded,
  ),
  _CommandItem(
    title: 'Instalar Entorno Dev (Python & Git)',
    category: 'Instalación',
    command: 'pkg install -y python python-pip git wget curl',
    description:
        'Instala Python 3, el gestor de paquetes pip, Git para clonar repositorios y utilidades de descarga HTTP/FTP.',
    icon: Icons.code_rounded,
  ),
  _CommandItem(
    title: 'Instalar Suite Auditing (Hydra & Sqlmap)',
    category: 'Instalación',
    command: 'pkg install -y hydra sqlmap nikto aria2',
    description:
        'Instala utilidades de verificación de seguridad web, análisis de vulnerabilidades y descargas multihilo aceleradas.',
    icon: Icons.security_rounded,
  ),
  _CommandItem(
    title: 'Instalar Utilidades (Htop & Neofetch)',
    category: 'Instalación',
    command: 'pkg install -y htop neofetch procps tree',
    description:
        'Instala monitores de sistema mejorados, visualizador de árbol de carpetas y comandos de resumen del sistema.',
    icon: Icons.widgets_rounded,
  ),

  // ⚙️ Sistema & Red
  _CommandItem(
    title: 'Listar Archivos Ocultos',
    category: 'Sistema',
    command: 'ls -la ~',
    description:
        'Muestra todos los archivos y carpetas del usuario incluyendo archivos de configuración ocultos (.bashrc, .config).',
    icon: Icons.folder_zip_rounded,
  ),
  _CommandItem(
    title: 'Directorio Actual (PWD)',
    category: 'Sistema',
    command: 'pwd',
    description: 'Imprime la ruta de trabajo actual en la estructura de archivos de Linux.',
    icon: Icons.folder_open_rounded,
  ),
  _CommandItem(
    title: 'Información de Distribución OS',
    category: 'Sistema',
    command: 'cat /etc/os-release',
    description: 'Muestra el nombre, versión, ID y soporte de la distribución Linux en ejecución.',
    icon: Icons.info_rounded,
  ),
  _CommandItem(
    title: 'Interfaces de Red IP (ip a)',
    category: 'Sistema',
    command: 'ip a',
    description: 'Muestra la lista de interfaces de red activas, dirección MAC y direcciones IPv4/IPv6 asignadas.',
    icon: Icons.wifi_tethering_rounded,
  ),
];
