import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/messaging/conversation_memory.dart';
import 'notification_history_provider.dart';

/// Vista estilizada de mensajes de historial de notificaciones Android estilo iOS (< 160 líneas).
class NotificationHistoryView extends ConsumerStatefulWidget {
  const NotificationHistoryView({
    super.key,
    required this.historyId,
    required this.bubble,
    this.fallback = const [],
  });

  final String historyId;
  final Widget Function(ConversationMemoryEntry entry) bubble;
  final List<ConversationMemoryEntry> fallback;

  @override
  ConsumerState<NotificationHistoryView> createState() =>
      _NotificationHistoryViewState();
}

class _NotificationHistoryViewState
    extends ConsumerState<NotificationHistoryView> {
  final Map<String, Map<String, dynamic>> _rows = {};
  bool _busy = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(NotificationHistoryView old) {
    super.didUpdateWidget(old);
    if (old.historyId != widget.historyId) {
      _rows.clear();
      _read();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _read();
    });
  }

  Future<void> _read() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final client = ref.read(notificationHistoryClientProvider);
      final results = await client.messages(
        widget.historyId,
        limit: 500,
      );
      if (mounted) {
        setState(() {
          for (final r in results) {
            _rows['${r['eventId']}'] = r;
          }
        });
      }
    } catch (_) {
      // Conserva el estado previo sin romper la UI.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _ordered() => _rows.values.toList()
    ..sort((a, b) {
      final time = (b['atMs'] as num).compareTo(a['atMs'] as num);
      return time != 0 ? time : '${b['eventId']}'.compareTo('${a['eventId']}');
    });

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        if (_busy && entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
          ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _busy ? 'Cargando mensajes…' : 'Sin mensajes previos',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (_, index) => widget.bubble(entries[index]),
                ),
        ),
      ],
    );
  }
}
