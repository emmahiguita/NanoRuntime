import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';

import '../../engine/agent_dependencies.dart';
import '../../engine/mcp/mcp_store_catalog.dart';
import '../../engine/orchestration/execution_journal.dart';
import '../automation_visual_theme.dart';
import '../widgets/mcp/mcp_graph_components.dart';
import '../widgets/mcp/mcp_hot_injection_dialog.dart';
import '../widgets/mcp/mcp_store_components.dart';
import '../widgets/mcp/mcp_telemetry_components.dart';
import '../widgets/mcp/mcp_tool_test_dialog.dart';

/// Hub visual interactivo para MCP (Model Context Protocol) y Skills de Nano AI.
///
/// Arquitectura limpia:
/// 1. Tab 1 - Grafo Vivo: topología reactiva entre Core, Servidores MCP y Skills.
/// 2. Tab 2 - Telemetría: auditoría en tiempo real del ExecutionJournal.
/// 3. Tab 3 - Tienda & Inyección: catálogo verificado e inyector HTTP/SSE en caliente.
class McpSkillsHubScreen extends ConsumerStatefulWidget {
  const McpSkillsHubScreen({super.key});

  @override
  ConsumerState<McpSkillsHubScreen> createState() => _McpSkillsHubScreenState();
}

class _McpSkillsHubScreenState extends ConsumerState<McpSkillsHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TransformationController _graphTransform;

  // Estado local para telemetría
  String _logFilter = 'all';
  bool _refreshingLogs = false;
  List<ExecutionJournalEntry> _journalEntries = const [];

  // Estado para la tienda
  String _storeSearchQuery = '';
  McpStoreCategory _selectedStoreCategory = McpStoreCategory.all;
  final TextEditingController _searchController = TextEditingController();
  final McpStoreCatalog _catalog = const McpStoreCatalog();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _graphTransform = TransformationController();
    _loadJournal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _graphTransform.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJournal() async {
    setState(() => _refreshingLogs = true);
    try {
      final journal = ref.read(executionJournalProvider);
      final entries = await journal.all();
      if (mounted) {
        setState(() {
          _journalEntries = entries.reversed.toList();
          _refreshingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _refreshingLogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visualMode = AutomationVisual.modeFromSetting(
      ref.watch(settingsProvider.select((settings) => settings.themeMode)),
    );

    return AnimatedTheme(
      data: AutomationVisual.theme(context, mode: visualMode),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Builder(
        builder: (context) {
          final visual = AutomationVisual.of(context);
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              fit: StackFit.expand,
              children: [
                const AutomationBackdrop(),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(context, visual),
                      _buildTabBar(visual),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildLiveGraphTab(visual),
                            _buildTelemetryTab(visual),
                            _buildStoreTab(visual),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AutomationVisualPalette visual) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Regresar',
            icon: const Icon(Icons.arrow_back_rounded, size: 24),
            color: visual.text,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hub de MCP & Skills',
                  style: TextStyle(
                    color: visual.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Grafo vivo de capacidades, telemetría y extensiones',
                  style: TextStyle(
                    color: visual.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refrescar Catálogo & Tools',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: visual.accent,
            onPressed: () async {
              final reg = ref.read(mcpConnectionRegistryProvider);
              final snap = await reg.refreshTools();
              await _loadJournal();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Catálogo sincronizado: ${snap.tools.length} tools activas.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AutomationVisualPalette visual) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: visual.cardStart,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: visual.cardBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: visual.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: visual.accent.withValues(alpha: 0.6)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: visual.accent,
        unselectedLabelColor: visual.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(icon: Icon(Icons.hub_outlined, size: 18), text: 'Grafo Vivo'),
          Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Telemetría'),
          Tab(icon: Icon(Icons.extension_outlined, size: 18), text: 'Tienda & Inyección'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: GRAFO VIVO INTERACTIVO (Detección de Servidores y Herramientas Reales)
  // ---------------------------------------------------------------------------

  Widget _buildLiveGraphTab(AutomationVisualPalette visual) {
    final mcpRegistry = ref.watch(mcpConnectionRegistryProvider);
    final mcpTools = mcpRegistry.lastTools;
    final systemGraphAsync = ref.watch(systemGraphProvider);
    final skillStore = ref.watch(skillStoreProvider);
    final approvedSkills = skillStore.approved();
    final deviceModel = systemGraphAsync.valueOrNull?.device.model ?? 'Samsung / Android';
    final appsCount = systemGraphAsync.valueOrNull?.apps.length ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        const canvasWidth = 960.0;
        const canvasHeight = 680.0;
        const centerOffset = Offset(canvasWidth / 2, canvasHeight / 2);

        if (_graphTransform.value.isIdentity() && constraints.maxWidth > 0) {
          final scale = (constraints.maxWidth / canvasWidth).clamp(0.48, 0.95);
          final dx = (constraints.maxWidth - canvasWidth * scale) / 2;
          final dy = (constraints.maxHeight - canvasHeight * scale) / 4;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _graphTransform.value = Matrix4.identity()
              ..setTranslationRaw(dx, dy, 0.0)
              ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
          });
        }

        // Construcción de Nodos
        final nodes = <McpGraphNode>[
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
              'status': 'OPERATIONAL',
              'mode': 'Candidate-First Local',
              'device': deviceModel,
              'installed_apps': appsCount,
              'servers_connected': mcpRegistry.servers.length,
              'tools_loaded': mcpTools.length + 3 + approvedSkills.length,
            },
          ),
          // 2. Capacidades de Plataforma del Dispositivo
          McpGraphNode(
            id: 'plat.accessibility',
            title: 'Accesibilidad',
            subtitle: 'Control UI & Tap',
            type: McpGraphNodeType.platform,
            offset: centerOffset + const Offset(-240, -120),
            icon: Icons.accessibility_new_rounded,
            statusColor: const Color(0xFFF59E0B),
            metadata: const {
              'service': 'AgentAccessibilityService',
              'status': 'ACTIVE',
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

        final edges = <McpGraphEdge>[
          const McpGraphEdge(from: 'core', to: 'plat.accessibility', color: Color(0xFFF59E0B)),
          const McpGraphEdge(from: 'core', to: 'plat.linux', color: Color(0xFFEC4899)),
          const McpGraphEdge(from: 'core', to: 'plat.nls', color: Color(0xFF14B8A6)),
          const McpGraphEdge(from: 'core', to: 'skill.open_app', color: Color(0xFF8B5CF6)),
          const McpGraphEdge(from: 'core', to: 'skill.system_nav', color: Color(0xFF8B5CF6)),
          const McpGraphEdge(from: 'core', to: 'skill.notifications', color: Color(0xFF8B5CF6)),
        ];

        // 4. Mapeo Dinámico de Servidores MCP y sus Herramientas (Sin hardcoding)
        final serverList = mcpRegistry.servers.toList();
        for (int sIdx = 0; sIdx < serverList.length; sIdx++) {
          final server = serverList[sIdx];
          final serverNodeId = 'mcp.server.${server.id}';
          final serverTools = mcpTools.values.where((t) => t.serverId == server.id).toList();

          final serverOffset = centerOffset +
              Offset(
                200.0,
                -180.0 + (sIdx * 130.0),
              );

          nodes.add(
            McpGraphNode(
              id: serverNodeId,
              title: server.displayName,
              subtitle: '${serverTools.length} tools • ${server.transport.name.toUpperCase()}',
              type: McpGraphNodeType.mcp,
              offset: serverOffset,
              icon: Icons.devices_other_rounded,
              statusColor: const Color(0xFF10B981),
              metadata: {
                'server_id': server.id,
                'status': 'CONNECTED',
                'transport': server.transport.name,
                'endpoint': server.endpoint ?? 'in-process',
                'tools_count': serverTools.length,
              },
            ),
          );
          edges.add(McpGraphEdge(from: 'core', to: serverNodeId, color: const Color(0xFF10B981)));

          // Nodos hijos de herramientas correspondientes a este servidor
          for (int tIdx = 0; tIdx < serverTools.length; tIdx++) {
            final tool = serverTools[tIdx];
            final toolNodeId = 'mcp.tool.${tool.qualifiedName}';
            final toolOffset = serverOffset +
                Offset(
                  150.0,
                  -35.0 + (tIdx * 58.0),
                );

            nodes.add(
              McpGraphNode(
                id: toolNodeId,
                title: tool.name,
                subtitle: 'Tool MCP',
                type: McpGraphNodeType.tool,
                offset: toolOffset,
                icon: Icons.build_circle_outlined,
                statusColor: const Color(0xFF38BDF8),
                metadata: {
                  'qualified_name': tool.qualifiedName,
                  'server_id': tool.serverId,
                  'description': tool.description,
                  'schema': tool.inputSchema,
                },
              ),
            );
            edges.add(McpGraphEdge(from: serverNodeId, to: toolNodeId, color: const Color(0xFF38BDF8)));
          }
        }

        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _graphTransform,
              boundaryMargin: const EdgeInsets.all(350),
              minScale: 0.45,
              maxScale: 2.5,
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(canvasWidth, canvasHeight),
                      painter: McpGraphEdgePainter(nodes: nodes, edges: edges),
                    ),
                    for (final node in nodes)
                      Positioned(
                        left: node.offset.dx - 66,
                        top: node.offset.dy - 34,
                        child: McpGraphNodeWidget(
                          node: node,
                          visual: visual,
                          onTap: () => showMcpNodeDetailsSheet(
                            context: context,
                            node: node,
                            visual: visual,
                            onTestTool: (targetNode) => showMcpToolTestDialog(
                              context: context,
                              node: targetNode,
                              registry: mcpRegistry,
                              visual: visual,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Controles flotantes de zoom y centrado
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: visual.cardStart.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: visual.cardBorder),
                  boxShadow: [
                    BoxShadow(color: visual.shadow, blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, size: 18),
                      color: visual.text,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final val = Matrix4.copy(_graphTransform.value);
                        val.scaleByDouble(1.2, 1.2, 1.0, 1.0);
                        _graphTransform.value = val;
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded, size: 18),
                      color: visual.text,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final val = Matrix4.copy(_graphTransform.value);
                        val.scaleByDouble(0.8, 0.8, 1.0, 1.0);
                        _graphTransform.value = val;
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                      color: visual.accent,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _graphTransform.value = Matrix4.identity(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: TELEMETRÍA Y AUDITORÍA DE EJECUCIONES
  // ---------------------------------------------------------------------------

  Widget _buildTelemetryTab(AutomationVisualPalette visual) {
    final filtered = _journalEntries.where((e) {
      if (_logFilter == 'mcp') return e.actionSignature.contains('mcp');
      if (_logFilter == 'skills') return e.semanticAction.isNotEmpty;
      if (_logFilter == 'failed') {
        return e.status == ExecutionJournalStatus.failed ||
            e.status == ExecutionJournalStatus.cancelled;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in [
                        ('all', 'Todos'),
                        ('mcp', 'MCP'),
                        ('skills', 'Skills'),
                        ('failed', 'Fallos'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            selected: _logFilter == f.$1,
                            label:
                                Text(f.$2, style: const TextStyle(fontSize: 12)),
                            selectedColor: visual.accent.withValues(alpha: 0.2),
                            checkmarkColor: visual.accent,
                            onSelected: (_) =>
                                setState(() => _logFilter = f.$1),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _refreshingLogs
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                color: visual.textMuted,
                onPressed: _refreshingLogs ? null : _loadJournal,
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No hay registros de telemetría disponibles.',
                    style: TextStyle(color: visual.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      McpTelemetryLogCard(entry: filtered[index], visual: visual),
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: TIENDA DE MCPS & INYECCIÓN EN CALIENTE
  // ---------------------------------------------------------------------------

  Widget _buildStoreTab(AutomationVisualPalette visual) {
    final mcpRegistry = ref.watch(mcpConnectionRegistryProvider);
    final connectedServerIds = mcpRegistry.servers.map((s) => s.id).toSet();
    final items = _catalog.query(
      searchQuery: _storeSearchQuery,
      category: _selectedStoreCategory,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Container(
          decoration: BoxDecoration(
            color: visual.cardStart,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: visual.cardBorder),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: visual.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar servidores MCP y Skills...',
              hintStyle: TextStyle(color: visual.textMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: visual.textMuted, size: 20),
              suffixIcon: _storeSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _storeSearchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) => setState(() => _storeSearchQuery = val),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final cat in McpStoreCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _selectedStoreCategory == cat,
                    label: Text(
                      switch (cat) {
                        McpStoreCategory.all => 'Todos',
                        McpStoreCategory.system => 'Sistema',
                        McpStoreCategory.developer => 'Desarrollo',
                        McpStoreCategory.search => 'Búsqueda Web',
                        McpStoreCategory.cloudAi => 'Cloud & IA',
                        McpStoreCategory.productivity => 'Productividad',
                      },
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedStoreCategory == cat ? FontWeight.w600 : FontWeight.w500,
                        color: _selectedStoreCategory == cat ? Colors.white : visual.text,
                      ),
                    ),
                    selectedColor: visual.accent,
                    backgroundColor: visual.cardStart,
                    side: BorderSide(
                      color: _selectedStoreCategory == cat ? visual.accent : visual.cardBorder,
                    ),
                    onSelected: (_) => setState(() => _selectedStoreCategory = cat),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                visual.accent.withValues(alpha: 0.18),
                visual.accent.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: visual.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: visual.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_to_photos_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inyección en Caliente (Hot Injection)',
                      style: TextStyle(color: visual.text, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Conecta servidores MCP locales/remotos SSE o endpoints JSON-RPC.',
                      style: TextStyle(color: visual.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: visual.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => showMcpHotInjectionDialog(
                  context: context,
                  registry: mcpRegistry,
                  visual: visual,
                  onInjected: (msg) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  },
                ),
                child: const Text('Inyectar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Servidores & Skills Disponibles (${items.length})',
              style: TextStyle(
                color: visual.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${connectedServerIds.length} activos',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Text(
              'No se encontraron servidores o skills para "$_storeSearchQuery"',
              style: TextStyle(color: visual.textMuted, fontSize: 13),
            ),
          )
        else
          for (final item in items)
            McpStoreItemCard(
              item: item,
              visual: visual,
              isConnected: connectedServerIds.contains(item.id),
              onConnect: () => showMcpStoreConnectDialog(
                context: context,
                item: item,
                registry: mcpRegistry,
                appCatalog: ref.read(installedAppCatalogProvider),
                visual: visual,
                onConnected: (msg) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                },
              ),
              onDisconnect: () async {
                await mcpRegistry.unregister(item.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Servidor ${item.name} desconectado.')),
                  );
                }
              },
            ),
      ],
    );
  }
}
