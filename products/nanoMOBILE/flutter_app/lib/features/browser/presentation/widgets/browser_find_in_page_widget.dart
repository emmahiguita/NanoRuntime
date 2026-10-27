import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'browser_icon_button.dart';

/// Búsqueda en la página, no en internet; conserva navegación de coincidencias.
class BrowserFindInPageWidget extends StatefulWidget {
  final InAppWebViewController? controller;
  final VoidCallback onClose;
  const BrowserFindInPageWidget({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  State<BrowserFindInPageWidget> createState() =>
      _BrowserFindInPageWidgetState();
}

class _BrowserFindInPageWidgetState extends State<BrowserFindInPageWidget> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  Timer? _pending;

  /// El foco se pide solo mientras la barra siga montada.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Al cambiar de pestaña no despacha una búsqueda pendiente al controlador nuevo.
  @override
  void didUpdateWidget(covariant BrowserFindInPageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _pending?.cancel();
  }

  /// Agrupa escritura rápida para evitar una llamada nativa por cada carácter.
  void _schedule(String text) {
    _pending?.cancel();
    if (text.isNotEmpty) {
      _pending = Timer(const Duration(milliseconds: 200), () => _find());
    }
  }

  /// JSON escapa comillas y saltos de línea antes de interpolarlos en JavaScript.
  Future<void> _find({bool backward = false}) async {
    _pending?.cancel();
    final query = _text.text.trim();
    if (!mounted || query.isEmpty || widget.controller == null) return;
    try {
      await widget.controller!.evaluateJavascript(
        source: 'window.find(${jsonEncode(query)}, false, $backward, true);',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo buscar en esta página.')),
        );
      }
    }
  }

  /// Cancela recursos propios; no detiene ni destruye la página web.
  @override
  void dispose() {
    _pending?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              onChanged: _schedule,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _find(),
              decoration: const InputDecoration(
                hintText: 'Buscar en la página',
                isDense: true,
              ),
            ),
          ),
          BrowserIconButton(
            icon: Icons.keyboard_arrow_up_rounded,
            label: 'Coincidencia anterior',
            onPressed: widget.controller == null
                ? null
                : () => _find(backward: true),
          ),
          BrowserIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            label: 'Siguiente coincidencia',
            onPressed: widget.controller == null ? null : () => _find(),
          ),
          BrowserIconButton(
            icon: Icons.close_rounded,
            label: 'Cerrar búsqueda',
            onPressed: widget.onClose,
          ),
        ],
      ),
    ),
  );
}
