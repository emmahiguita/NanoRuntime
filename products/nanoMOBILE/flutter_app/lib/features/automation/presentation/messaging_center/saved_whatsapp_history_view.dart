import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/web_bridge/whatsapp_web_history_message.dart';
import '../../engine/web_bridge/whatsapp_web_history_reader.dart';
import '../../engine/web_bridge/whatsapp_web_history_store.dart';

/// Historial guardado primero. La Web se prepara detrás sin bloquear estas filas.
class SavedWhatsAppHistoryView extends StatefulWidget {
  final String alias;
  final Widget Function(ConversationMemoryEntry) bubble;
  final ValueListenable<int> revision;
  final bool ready;
  final bool autoOpenWebIfEmpty;
  final String? error;
  final VoidCallback onWeb, onRetry;
  const SavedWhatsAppHistoryView({
    super.key,
    required this.alias,
    required this.bubble,
    required this.revision,
    required this.ready,
    required this.autoOpenWebIfEmpty,
    required this.error,
    required this.onWeb,
    required this.onRetry,
  });
  @override
  State<SavedWhatsAppHistoryView> createState() =>
      _SavedWhatsAppHistoryViewState();
}

class _SavedWhatsAppHistoryViewState extends State<SavedWhatsAppHistoryView> {
  // Solo diez páginas recientes; no retiene todo el historial ni archivos originales.
  static final _cache = <String, List<WhatsAppWebHistoryMessage>>{};
  final _store = WhatsAppWebHistoryStore();
  final _rows = <String, WhatsAppWebHistoryMessage>{};
  bool _busy = false, _more = false, _reload = false, _paged = false;
  bool _hasRead = false, _openingWeb = false;
  String? _readError;
  List<WhatsAppWebHistoryMessage> get _ordered =>
      _rows.values.toList()..sort((a, b) {
        final time = b.atMs.compareTo(a.atMs);
        return time != 0 ? time : b.eventId.compareTo(a.eventId);
      });
  @override
  void initState() {
    super.initState();
    for (final row in _cache[widget.alias] ?? <WhatsAppWebHistoryMessage>[]) {
      _rows[row.eventId] = row;
    }
    widget.revision.addListener(_refresh);
    unawaited(_read());
  }

  void _refresh() => unawaited(_read());
  @override
  void didUpdateWidget(covariant SavedWhatsAppHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeOpenWeb();
  }

  // Sin archivo verificado usa el original; nunca cambia una lista ya poblada.
  void _maybeOpenWeb() {
    if (_openingWeb ||
        !_hasRead ||
        _busy ||
        _rows.isNotEmpty ||
        !widget.ready ||
        !widget.autoOpenWebIfEmpty) {
      return;
    }
    _openingWeb = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.ready && widget.autoOpenWebIfEmpty && _rows.isEmpty) {
        widget.onWeb();
      }
    });
  }

  @override
  void dispose() {
    widget.revision.removeListener(_refresh);
    super.dispose();
  }

  /// Lectura serializada y paginada; conservar filas evita parpadeos al sincronizar.
  Future<void> _read({bool earlier = false}) async {
    if (!mounted) return;
    if (_busy) {
      _reload = true;
      return;
    }
    setState(() {
      _busy = true;
      _readError = null;
    });
    try {
      final account = await WhatsAppWebHistoryReader.forAlias(
        widget.alias,
      ).knownAccount();
      if (account == null) throw StateError('Cuenta no identificada');
      final rows = _ordered;
      final watch = Stopwatch()..start();
      final page = await _store.page(
        account,
        widget.alias,
        before: earlier && rows.isNotEmpty ? rows.last : null,
      );
      if (!mounted) return;
      for (final row in page.rows) {
        _rows[row.eventId] = row;
      }
      if (earlier || !_paged) _more = page.hasMore;
      _paged |= earlier;
      if (!earlier) {
        _cache.remove(widget.alias);
        _cache[widget.alias] = List.unmodifiable(page.rows);
        if (_cache.length > 10) _cache.remove(_cache.keys.first);
      }
      debugPrint(
        '[wa-saved-page] elapsedMs=${watch.elapsedMilliseconds} rows=${page.rows.length}',
      );
    } catch (_) {
      if (mounted) _readError = 'No se pudo actualizar el archivo local.';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _hasRead = true;
        _maybeOpenWeb();
        if (_reload) {
          _reload = false;
          unawaited(_read());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _ordered;
    // La memoria heredada no demuestra procedencia Web: solo filas verificadas.
    final entries = rows.map((r) => r.entry).toList();
    return ColoredBox(
      // No mezcla el DOM que se prepara detrás con las burbujas guardadas.
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0A0F1D)
          : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: const Text('Historial guardado · cobertura parcial'),
            subtitle: Text(
              _readError ??
                  widget.error ??
                  (widget.ready
                      ? 'Sincronizando lo visible en segundo plano'
                      : 'Preparando sesión Web…'),
            ),
            trailing: TextButton(
              onPressed: widget.ready ? widget.onWeb : widget.onRetry,
              child: Text(widget.ready ? 'Vista Web' : 'Reintentar'),
            ),
          ),
          if (_more)
            TextButton(
              onPressed: _busy ? null : () => _read(earlier: true),
              child: const Text('Cargar anteriores guardados'),
            ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      _busy
                          ? 'Leyendo mensajes guardados…'
                          : 'Sin mensajes Web guardados verificables. Usa Vista Web para ver el historial original.',
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (_, i) => widget.bubble(entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
