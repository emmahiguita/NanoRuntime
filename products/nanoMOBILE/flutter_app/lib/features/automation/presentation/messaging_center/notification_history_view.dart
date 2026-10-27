import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/messaging/conversation_memory.dart';
import 'notification_history_provider.dart';

/// Historial local por páginas: muestra mensajes observados, nunca previews fabricados.
class NotificationHistoryView extends ConsumerStatefulWidget {
  final String historyId;
  final List<ConversationMemoryEntry> fallback;
  final Widget Function(ConversationMemoryEntry) bubble;
  const NotificationHistoryView({
    super.key,
    required this.historyId,
    required this.fallback,
    required this.bubble,
  });
  @override
  ConsumerState<NotificationHistoryView> createState() =>
      _NotificationHistoryViewState();
}

class _NotificationHistoryViewState
    extends ConsumerState<NotificationHistoryView> {
  final _rows = <String, Map<String, dynamic>>{};
  bool _busy = false, _hasMore = false, _paged = false, _reload = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    for (final row
        in ref
            .read(notificationHistoryClientProvider)
            .cachedPage(widget.historyId)) {
      _rows['${row['eventId']}'] = row;
    }
    unawaited(_read());
  }

  /// Agrupa ráfagas de persistencia y cancela el trabajo diferido al cerrar.
  void _scheduleRefresh() {
    // Throttle, no debounce: una ráfaga continua no pospone la lectura para siempre.
    if (_refreshTimer?.isActive == true) return;
    _refreshTimer = Timer(
      const Duration(milliseconds: 180),
      () => unawaited(_read()),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Serializa lecturas y agrupa invalidaciones; un stream no crea consultas ilimitadas.
  Future<void> _read({bool earlier = false}) async {
    if (!mounted) return;
    if (_busy) {
      if (!earlier) _reload = true;
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final watch = Stopwatch()..start();
      final ordered = _ordered();
      final page = await ref
          .read(notificationHistoryClientProvider)
          .page(
            widget.historyId,
            before: earlier && ordered.isNotEmpty ? ordered.last : null,
          );
      if (!mounted) return;
      debugPrint(
        '[wa-history-page] elapsedMs=${watch.elapsedMilliseconds} rows=${page.rows.length} earlier=$earlier',
      );
      for (final row in page.rows) {
        final id = '${row['eventId'] ?? ''}';
        if (id.isNotEmpty) _rows[id] = row;
      }
      if (earlier || !_paged) _hasMore = page.hasMore;
      _paged |= earlier;
    } catch (_) {
      _error =
          'No se pudo leer esta página. Los mensajes guardados no se borraron.';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_reload) {
          _reload = false;
          unawaited(_read());
        }
      }
    }
  }

  /// Usa exactamente el mismo orden compuesto del cursor SQLite.
  List<Map<String, dynamic>> _ordered() => _rows.values.toList()
    ..sort((a, b) {
      final time = (b['atMs'] as num).compareTo(a['atMs'] as num);
      return time != 0 ? time : '${b['eventId']}'.compareTo('${a['eventId']}');
    });

  /// La dirección llega de MessagingStyle; no la deduce del nombre o del texto.
  ConversationMemoryEntry _entry(Map<String, dynamic> row) =>
      ConversationMemoryEntry(
        eventId: '${row['eventId']}',
        text: '${row['body']}',
        sender: '${row['sender']}',
        atMs: (row['atMs'] as num).toInt(),
        kind: row['isSelf'] == true
            ? ConversationMemoryEntryKind.outboundObservedManual
            : ConversationMemoryEntryKind.inbound,
      );

  @override
  Widget build(BuildContext context) {
    ref.listen(
      notificationHistoryEventsProvider,
      (_, __) => _scheduleRefresh(),
    );
    final rows = _ordered();
    final entries = rows.isNotEmpty
        ? rows.map(_entry).toList()
        : widget.fallback.reversed
              .where(
                (entry) =>
                    entry.kind == ConversationMemoryEntryKind.inbound ||
                    entry.kind ==
                        ConversationMemoryEntryKind.outboundObservedManual ||
                    entry.kind == ConversationMemoryEntryKind.outboundVerified,
              )
              .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historial registrado por Android · ${rows.length} mensajes cargados',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null)
                Text(_error!, style: Theme.of(context).textTheme.bodySmall),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _read(),
                    child: const Text('Actualizar'),
                  ),
                  if (_hasMore)
                    TextButton(
                      onPressed: _busy ? null : () => _read(earlier: true),
                      child: const Text('Cargar anteriores'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _busy
                        ? 'Cargando historial…'
                        : 'Sin mensajes registrados por Android',
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (_, index) => widget.bubble(entries[index]),
                ),
        ),
      ],
    );
  }
}
