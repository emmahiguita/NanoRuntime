import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'noar_builtin_commands.dart';

part 'noar_panel_card.part.dart';
part 'noar_panel_header.part.dart';
part 'noar_panel_tags.part.dart';

/// Noar Command Library — ventana flotante estilo iOS Glass (TER-15).
/// Presenta comandos verificados de Linux con alta legibilidad en temas
/// claro y oscuro, chips de categoría y ejecución en 1 tap.
class NoarPanel extends StatefulWidget {
  final List<Map<String, dynamic>> library;
  final Color fg;
  final bool dark;

  /// Ejecuta el comando en el terminal activo (bash PTY real o dispatcher).
  /// El panel se cierra tras usarlo.
  final void Function(String cmd)? onUse;

  const NoarPanel({
    super.key,
    required this.library,
    required this.fg,
    required this.dark,
    this.onUse,
  });

  @override
  State<NoarPanel> createState() => _NoarPanelState();
}

class _NoarPanelState extends State<NoarPanel> {
  String _search = '';
  String _activeTag = 'all';
  final _searchCtl = TextEditingController();

  static const Color _accent = Color(0xFF10B981);

  List<Map<String, dynamic>> get _filtered {
    final all = [...noarBuiltinCommands, ...widget.library];
    return all.where((c) {
      final tag = c['tag'] as String? ?? 'general';
      if (_activeTag != 'all' && tag != _activeTag) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final cmd = (c['cmd'] as String? ?? '').toLowerCase();
        final desc = (c['desc'] as String? ?? '').toLowerCase();
        if (!cmd.contains(q) && !desc.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copiado: $text',
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  void _use(String cmd) {
    HapticFeedback.mediumImpact();
    if (widget.onUse == null) {
      _copy(cmd);
      return;
    }
    widget.onUse!(cmd);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.dark;
    final items = _filtered;
    final mq = MediaQuery.sizeOf(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.height * 0.84),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NoarHeader(
            itemCount: items.length,
            isDark: isDark,
            accent: _accent,
          ),
          _NoarSearchBar(
            controller: _searchCtl,
            isDark: isDark,
            accent: _accent,
            onChanged: (v) => setState(() => _search = v.trim()),
            onClear: () {
              _searchCtl.clear();
              setState(() => _search = '');
            },
          ),
          _NoarTagSelector(
            activeTag: _activeTag,
            isDark: isDark,
            accent: _accent,
            onSelectTag: (tag) => setState(() => _activeTag = tag),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Sin resultados para la búsqueda',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final cmd = items[i];
                      return _NoarCommandCard(
                        cmd: cmd,
                        tagLabel: _noarTagLabel(cmd['tag'] as String?),
                        isHistory: cmd.containsKey('ts'),
                        isDark: isDark,
                        accent: _accent,
                        onCopy: () => _copy(cmd['cmd'] as String? ?? ''),
                        onUse: () => _use(cmd['cmd'] as String? ?? ''),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
