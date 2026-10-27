part of 'terminal_hub_screen.dart';

/// Describe destinos reales; la ficha no certifica instalación.
extension _TerminalHubCards on _TerminalHubScreenState {
  List<TerminalHubCard> _buildCards(NanoColors colors) {
    return [
      TerminalHubCard(
        id: 'terminal',
        title: 'Terminal',
        eyebrow: 'CONSOLA PTY',
        description:
            'Sesiones interactivas persistentes para Bash, Python, Node, SSH y utilidades nativas.',
        icon: Icons.hub_rounded,
        accent: colors.accent,
        imageAsset: 'assets/promo/ad1.jpg',
        route: '/terminal/shell',
        highlights: const [
          'Sesiones PTY independientes con salida real',
          'Editor conectado a la pestaña seleccionada',
          'Comandos guardados accesibles desde el menú',
        ],
        actionLabel: 'Abrir Consola PTY',
      ),
      TerminalHubCard(
        id: 'shell_linux',
        title: 'SHELL LINUX',
        eyebrow: 'ENTORNOS',
        description:
            'Administra Termux y las distribuciones compatibles. La disponibilidad se comprueba en cada instalación.',
        icon: Icons.terminal_rounded,
        accent: colors.terminalGreen,
        imageAsset: 'assets/promo/ad2.jpg',
        route: '/linux',
        highlights: const [
          'Emulador de terminal VT100 completo con soporte de colores',
          'Aislamiento seguro de procesos sin necesidad de root',
          'Integración nativa con Nano Runtime y sockets locales',
        ],
        actionLabel: 'Administrar Entornos',
      ),
      // MÓDULO VISOR LINUX (GUI / X11 VNC) — OPCIONAL BAJO DEMANDA
      // QUÉ HACE:
      // Ofrece acceso al escritorio gráfico X11 remoto mediante un cliente RFB 3.8.
      // POR QUÉ ES OPCIONAL:
      // Para desarrollo y automatización el Modo Terminal es suficiente y 10x más ligero.
      // Este módulo se mantiene disponible para usuarios que requieran software estrictamente gráfico.
      TerminalHubCard(
        id: 'visor_linux',
        title: 'Visor Linux (GUI)',
        eyebrow: 'ESCRITORIO (OPCIONAL)',
        description:
            'Entorno gráfico X11 y visor remoto VNC bajo demanda. Opcional para apps de escritorio.',
        icon: Icons.desktop_windows_rounded,
        accent: colors.tertiary,
        imageAsset: 'assets/promo/ad3.jpg',
        route: '/desktop',
        highlights: const [
          'Opcional bajo demanda: no consume recursos hasta activarse',
          'Soporte de gestos táctiles, trackpad virtual y teclado físico',
          'Aceleración de renderizado RFB con zoom dinámico',
        ],
        actionLabel: 'Abrir Visor Opcional',
      ),
      TerminalHubCard(
        id: 'data_studio',
        title: 'Data Studio',
        eyebrow: 'SQL Y REPORTES',
        description:
            'Conecta hojas de cálculo Shell (CSV/TSV), ejecuta consultas SQL y genera informes PDF ejecutivos.',
        icon: Icons.table_chart_rounded,
        accent: colors.accent,
        imageAsset: 'assets/promo/ad1.jpg',
        route: '/database',
        highlights: const [
          'Conexión nativa con archivos CSV/TSV del entorno Shell',
          'Motor SQL en memoria y soporte de bases de datos SQLite',
          'Generación, impresión y exportación de informes ejecutivos en PDF',
        ],
        actionLabel: 'Abrir Data Studio',
      ),
    ];
  }
}
