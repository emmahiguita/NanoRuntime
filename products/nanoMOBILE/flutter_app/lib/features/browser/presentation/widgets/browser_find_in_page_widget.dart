import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Barra de búsqueda flotante "Buscar en la página" estilo iOS Safari.
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
  final TextEditingController _findCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _findCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _findNext({bool backward = false}) {
    final text = _findCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    final escaped = text.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    widget.controller?.evaluateJavascript(
      source: "window.find('$escaped', false, $backward, true);",
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return ClipRRect(
      borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: isLandscape ? 32 : 46,
          padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 10, vertical: isLandscape ? 1 : 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xE80D1D2C) : const Color(0xF2F1F5F9),
            borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF10B981).withValues(alpha: 0.45)
                  : const Color(0xFF2563EB).withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: isLandscape ? 8 : 16,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: isLandscape ? 14 : 18,
                color: const Color(0xFF10B981),
              ),
              SizedBox(width: isLandscape ? 5 : 8),
              Expanded(
                child: TextField(
                  controller: _findCtrl,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _findNext(backward: false),
                  onChanged: (val) {
                    if (val.isNotEmpty) _findNext(backward: false);
                  },
                  style: TextStyle(
                    fontSize: isLandscape ? 11 : 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar en la página...',
                    hintStyle: TextStyle(fontSize: isLandscape ? 10.5 : 12, color: Colors.grey),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              // Botón anterior
              IconButton(
                icon: Icon(Icons.keyboard_arrow_up_rounded, size: isLandscape ? 16 : 20),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: isLandscape ? 22 : 28, minHeight: isLandscape ? 22 : 28),
                onPressed: () => _findNext(backward: true),
              ),
              // Botón siguiente
              IconButton(
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: isLandscape ? 16 : 20),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: isLandscape ? 22 : 28, minHeight: isLandscape ? 22 : 28),
                onPressed: () => _findNext(backward: false),
              ),
              SizedBox(width: isLandscape ? 2 : 4),
              // Botón cerrar táctil
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onClose();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: isLandscape ? 22 : 26,
                  height: isLandscape ? 22 : 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  child: Icon(Icons.close_rounded, size: isLandscape ? 12 : 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
