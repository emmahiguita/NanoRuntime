/// VAL-UI — Sección Dev de validación física del edge.
///
/// Superficie de prueba manual para los sprints del búho:
/// - EDGE-01/03: badge de disponibilidad + conmutador de burbuja.
/// - ROLE-01: botón explícito de assistant role.
/// - APPFN-01: sonda de App Functions (canal nativo, solo lectura).
/// - WA-MIRROR-01: espejo de conversación (historial, resumen, búsqueda).
///
/// Solo diagnóstico, como el resto de la pantalla Dev. Los widgets de control
/// del overlay viven en nano_edge_overlay.dart; aquí se exponen. El espejo es
/// read-only: jamás escribe ni ejecuta.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_section_card.dart';
import 'package:nanoai/features/automation/engine/agent_dependencies.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';

import 'nano_edge_overlay.dart';
import 'panels/conversation_mirror.dart';
import 'panels/conversation_search.dart';

/// Bloque de validación física del edge para la pantalla Dev.
class EdgeDevSection extends StatelessWidget {
  const EdgeDevSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NanoSectionCard(
          title: 'Búho (EDGE-01/03 · ROLE-01)',
          child: Column(            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NanoEdgeStatusBadge(),
              SizedBox(height: NanoSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionLabel('Burbuja sobre apps'),
                  NanoEdgeBubbleToggle(),
                ],
              ),
              SizedBox(height: NanoSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: NanoAssistantRoleButton(),
              ),
            ],
          ),
        ),
        SizedBox(height: NanoSpacing.lg),
        _AppFunctionProbeCard(),
        SizedBox(height: NanoSpacing.lg),
        _ConversationMirrorCard(),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Text(text, style: NanoType.label(colors.onSurfaceVariant));
  }
}

/// APPFN-01 — sonda de App Functions (Android 16+). Solo lectura del canal
/// nativo `appfunctions/probe`; el resultado es el mapa factual del handler
/// (sdk, apiSupported, permissionDeclared/Granted, available, reason).
class _AppFunctionProbeCard extends StatefulWidget {
  const _AppFunctionProbeCard();

  @override
  State<_AppFunctionProbeCard> createState() => _AppFunctionProbeCardState();
}

class _AppFunctionProbeCardState extends State<_AppFunctionProbeCard> {
  static const _channel = MethodChannel('appfunctions/probe');

  bool _busy = false;
  Map<Object?, Object?>? _result;
  String? _error;

  Future<void> _probe() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>('probe');
      setState(() => _result = map);
    } on Object catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final result = _result;
    return NanoSectionCard(
      title: 'App Functions (APPFN-01)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _probe,
            icon: const Icon(Icons.radar, size: 18),
            label: const Text('Sondear disponibilidad'),
          ),
          const SizedBox(height: NanoSpacing.sm),
          if (_error != null)
            Text(
              'Canal no disponible: $_error',
              style: NanoType.caption(colors.error),
            )
          else if (result != null)
            Text(
              [
                'sdkInt: ${result['sdkInt']}',
                'apiSupported: ${result['apiSupported']}',
                'permissionDeclared: ${result['permissionDeclared']}',
                'permissionGranted: ${result['permissionGranted']}',
                'available: ${result['available']}',
                'reason: ${result['reason']}',
              ].join('\n'),
              style: NanoType.body(colors.onSurfaceVariant),
            )
          else
            Text(
              'Sin sondeo aún.',
              style: NanoType.caption(colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// WA-MIRROR-01 — espejo de conversación: lista las conversaciones con
/// memoria retenida, muestra el historial honesto (kinds reales), genera
/// resumen y busca localmente. Todo read-only.
class _ConversationMirrorCard extends ConsumerStatefulWidget {
  const _ConversationMirrorCard();

  @override
  ConsumerState<_ConversationMirrorCard> createState() =>
      _ConversationMirrorCardState();
}

class _ConversationMirrorCardState
    extends ConsumerState<_ConversationMirrorCard> {
  final _searchController = TextEditingController();

  List<String> _ids = const [];
  String? _selectedId;
  ConversationMirrorData? _data;
  String _summary = '';
  bool _summaryLlm = false;
  List<ConversationSearchHit> _hits = const [];

  @override
  void initState() {
    super.initState();
    // Async: la hidratación del store tarda; el setState va con guard mounted.
    _refreshIds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshIds() async {
    final store = ref.read(conversationMemoryStoreProvider);
    // El store se hidrata asíncrono (load() al crear el provider): esperar
    // evita leer vacío por raza en el primer build.
    await store.load();
    final ids = store.knownConversationIds().toList()..sort();
    if (mounted) setState(() => _ids = ids);
  }

  /// Reconstruye la clave desde su id serializado
  /// (`canal/paquete/cuenta|‑/huella`). Huella puede contener '/'.
  static ConversationKey _keyFromId(String id) {
    final parts = id.split('/');
    return ConversationKey(
      channel: parts.isEmpty ? '' : parts[0],
      appPackage: parts.length > 1 ? parts[1] : '',
      accountFingerprint: parts.length > 2 && parts[2] != '-' ? parts[2] : '',
      conversationFingerprint: parts.length > 3
          ? parts.sublist(3).join('/')
          : '',
    );
  }

  Future<void> _load(String id) async {
    setState(() {
      _selectedId = id;
      _data = null;
      _summary = '';
      _hits = const [];
    });
    final data = await ref
        .read(conversationMirrorProvider)
        .load(_keyFromId(id));
    if (mounted) setState(() => _data = data);
  }

  Future<void> _summarize() async {
    final id = _selectedId;
    if (id == null) return;
    setState(() => _summary = '');
    final summary = await ref
        .read(conversationMirrorProvider)
        .summarize(_keyFromId(id));
    if (mounted) {
      setState(() {
        _summary = summary.text;
        _summaryLlm = summary.llmGenerated;
      });
    }
  }

  Future<void> _search() async {
    final id = _selectedId;
    if (id == null) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final hits = await ref
        .read(conversationMirrorProvider)
        .search(_keyFromId(id), query);
    if (mounted) setState(() => _hits = hits);
  }

  static String _hhmm(int atMs) {
    final t = DateTime.fromMillisecondsSinceEpoch(atMs);
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final data = _data;
    return NanoSectionCard(
      title: 'Espejo de conversación (WA-MIRROR-01)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.refresh, size: 16),
              TextButton(
                onPressed: _refreshIds,
                child: const Text('Actualizar conversaciones'),
              ),
            ],
          ),
          if (_ids.isEmpty)
            Text(
              'Sin conversaciones con memoria retenida.',
              style: NanoType.caption(colors.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: NanoSpacing.xs,
              runSpacing: NanoSpacing.xs,
              children: [
                for (final id in _ids)
                  ChoiceChip(
                    label: Text(
                      id.length > 48 ? '${id.substring(0, 48)}…' : id,
                      style: NanoType.caption(
                        _selectedId == id
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    selected: _selectedId == id,
                    onSelected: (_) => _load(id),
                  ),
              ],
            ),
          if (data != null) ...[
            const SizedBox(height: NanoSpacing.sm),
            Text(
              'entrante ${data.inboundCount} · enviado verificado '
              '${data.outboundVerifiedCount} · despachado '
              '${data.outboundDispatchedCount} · efecto incierto '
              '${data.effectUnknownCount}',
              style: NanoType.caption(colors.onSurfaceVariant),
            ),
            const SizedBox(height: NanoSpacing.xs),
            for (final entry in data.entries.take(20))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${_hhmm(entry.atMs)} [${entry.kind.name}]'
                  '${entry.sender.isEmpty ? '' : ' ${entry.sender}'}: '
                  '${entry.text}',
                  style: NanoType.caption(colors.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: NanoSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _summarize,
                    icon: const Icon(Icons.summarize, size: 18),
                    label: const Text('Resumen'),
                  ),
                ),
              ],
            ),
            if (_summary.isNotEmpty) ...[
              const SizedBox(height: NanoSpacing.xs),
              Text(
                '${_summaryLlm ? '[LLM] ' : '[determinista] '}$_summary',
                style: NanoType.body(colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: NanoSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Buscar en la memoria…',
                    ),
                  ),
                ),
                const SizedBox(width: NanoSpacing.sm),
                IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                  tooltip: 'Buscar',
                ),
              ],
            ),
            for (final hit in _hits.take(10))
              Text(
                'score ${hit.score} · ${_hhmm(hit.entry.atMs)} '
                '[${hit.entry.kind.name}] ${hit.entry.text}',
                style: NanoType.caption(colors.onSurfaceVariant),
              ),
          ],
        ],
      ),
    );
  }
}
