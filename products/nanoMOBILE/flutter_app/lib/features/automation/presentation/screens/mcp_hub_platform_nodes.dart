part of 'mcp_skills_hub_screen.dart';

/// Presentación MCP: platform nodes; no ejecuta herramientas.
extension _McpHubPlatformNodes on _McpSkillsHubScreenState {
  List<McpGraphNode> _platformNodes(
    AutomationVisualPalette visual,
    Offset centerOffset,
    String deviceModel,
    int? appsCount,
  ) {
    final mcpRegistry = ref.watch(mcpConnectionRegistryProvider);
    final connectedServerIds = mcpRegistry.connectedServerIds;
    final mcpTools = mcpRegistry.lastTools;
    final accessibility = ref.watch(mcpAccessibilityStatusProvider).valueOrNull;
    return <McpGraphNode>[
      // 1. Nodo Central: Core
      McpGraphNode(
        id: 'core',
        title: 'Nano Core Engine',
        subtitle: 'Orquestador Local ($deviceModel)',
        type: McpGraphNodeType.core,
        offset: centerOffset,
        icon: Icons.psychology_rounded,
        statusColor: visual.accent,
        metadata: {
          'status': mcpRegistry.lastSnapshot == null
              ? 'SIN CONSULTAR'
              : mcpRegistry.lastSnapshot!.failures.isEmpty
              ? 'CATÁLOGO CONSULTADO'
              : 'CATÁLOGO PARCIAL',
          'mode': 'Candidate-First Local',
          'device': deviceModel,
          'installed_apps': appsCount,
          'servers_connected': connectedServerIds.length,
          'tools_loaded': mcpTools.length,
        },
      ),
      // 2. Capacidades de Plataforma del Dispositivo
      McpGraphNode(
        id: 'plat.accessibility',
        title: 'Accesibilidad',
        subtitle: accessibility == null
            ? 'Estado sin verificar'
            : accessibility
            ? 'Servicio conectado'
            : 'Servicio desconectado',
        type: McpGraphNodeType.platform,
        offset: centerOffset + const Offset(-240, -120),
        icon: Icons.accessibility_new_rounded,
        // No se deduce el permiso a partir de la presencia de un nodo.
        statusColor: visual.accent,
        metadata: {
          'service': 'AgentAccessibilityService',
          'status': accessibility == null
              ? 'DESCONOCIDO'
              : accessibility
              ? 'CONECTADO'
              : 'DESCONECTADO',
          'features': 'ViewTree, Semantics, Taps, Gestures',
        },
      ),
      McpGraphNode(
        id: 'plat.linux',
        title: 'Linux Runtime',
        subtitle: 'PTY & Shell NDK',
        type: McpGraphNodeType.platform,
        offset: centerOffset + const Offset(-270, 0),
        icon: Icons.terminal_rounded,
        statusColor: const Color(0xFFEC4899),
        metadata: const {
          'backend': 'pty_session_registry (C/JNI)',
          'safety': 'Non-blocking WNOHANG cleanup',
        },
      ),
      McpGraphNode(
        id: 'plat.nls',
        title: 'Notificaciones',
        subtitle: 'NLS + RemoteInput',
        type: McpGraphNodeType.platform,
        offset: centerOffset + const Offset(-240, 120),
        icon: Icons.mark_chat_read_rounded,
        statusColor: const Color(0xFF14B8A6),
        metadata: const {
          'service': 'AgentNotificationListenerService',
          'replies': 'Direct Quick Reply Inline',
        },
      ),
      // 3. Skills Nativas del Dispositivo
      McpGraphNode(
        id: 'skill.open_app',
        title: 'Open App',
        subtitle: 'Skill Catálogo',
        type: McpGraphNodeType.skill,
        offset: centerOffset + const Offset(190, 120),
        icon: Icons.launch_rounded,
        statusColor: const Color(0xFF8B5CF6),
        metadata: const {
          'id': 'open_app',
          'grounded': 'InstalledAppCatalog',
          'type': 'CandidateProvider',
        },
      ),
      McpGraphNode(
        id: 'skill.system_nav',
        title: 'System Nav',
        subtitle: 'Skill Intents',
        type: McpGraphNodeType.skill,
        offset: centerOffset + const Offset(290, 190),
        icon: Icons.settings_suggest_rounded,
        statusColor: const Color(0xFF8B5CF6),
        metadata: const {
          'id': 'system_navigation',
          'grounded': 'SystemIntentCatalog',
          'type': 'CandidateProvider',
        },
      ),
      McpGraphNode(
        id: 'skill.notifications',
        title: 'Read Alerts',
        subtitle: 'Skill NLS',
        type: McpGraphNodeType.skill,
        offset: centerOffset + const Offset(160, 230),
        icon: Icons.notifications_active_outlined,
        statusColor: const Color(0xFF8B5CF6),
        metadata: const {
          'id': 'read_notifications',
          'grounded': 'NotificationListenerService',
          'type': 'CandidateProvider',
        },
      ),
    ];
  }
}
