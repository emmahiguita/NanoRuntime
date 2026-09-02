import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Barra de modificadores del terminal (PTY interactivo).
///
/// TER-13: rediseño profesional — sin verde neón en las teclas. Paleta
/// pizarra/cian (estilo terminal moderno), teclas con fondo sólido,
/// grupos separados por divisores, animación de presión (escala) y
/// transición de color animada para el estado activo (Ctrl sticky).
class TerminalModifierBar extends StatelessWidget {
  const TerminalModifierBar({
    super.key,
    required this.fg,
    required this.chrome,
    required this.ctrlActive,
    required this.onToggleCtrl,
    required this.onWriteBytes,
    required this.onWrite,
    this.bracketedPasteEnabled = false,
  });

  final Color fg;
  final Color chrome;
  final bool ctrlActive;
  final VoidCallback onToggleCtrl;
  final void Function(List<int> bytes) onWriteBytes;
  final void Function(String text) onWrite;

  /// Whether the remote program has negotiated bracketed paste mode (?2004).
  final bool bracketedPasteEnabled;

  // TER-13: paleta pizarra/cian profesional.
  static const Color _keyBg = Color(0xFF13243C);
  static const Color _keyBgLight = Color(0xFFD3D9E5);
  static const Color _keyFg = Color(0xFF9FB3C8);
  static const Color _keyFgLight = Color(0xFF46536B);
  static const Color _accent = Color(0xFF38BDF8);

  @override
  Widget build(BuildContext context) {
    final dark = chrome.computeLuminance() < 0.5;
    final keyBg = dark ? _keyBg : _keyBgLight;
    final keyFg = dark ? _keyFg : _keyFgLight;

    Widget divider() => Container(
          width: 1,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.07),
        );

    Widget key(String label, VoidCallback onTap,
        {String? longLabel, bool active = false}) {
      return _AnimatedKey(
        label: longLabel ?? label,
        onTap: onTap,
        active: active,
        keyBg: keyBg,
        keyFg: keyFg,
        accent: _accent,
      );
    }

    return Container(
      color: chrome,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 5,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          key('Esc', () => onWriteBytes([0x1b])),
          key('Ctrl', onToggleCtrl,
              longLabel: ctrlActive ? 'Ctrl ON' : 'Ctrl', active: ctrlActive),
          key('Tab', () => onWriteBytes([0x09])),
          divider(),
          // TER-11: señales (0x03 por ISIG del kernel genera el SIGINT —
          // sin kill() desde la app: seccomp ColorOS hostil).
          key('Ctrl+C', () => onWriteBytes([0x03])),
          key('Ctrl+D', () => onWriteBytes([0x04])),
          key('Ctrl+Z', () => onWriteBytes([0x1a])),
          divider(),
          key('←', () => onWriteBytes([0x1b, 0x5b, 0x44])),
          key('↓', () => onWriteBytes([0x1b, 0x5b, 0x42])),
          key('↑', () => onWriteBytes([0x1b, 0x5b, 0x41])),
          key('→', () => onWriteBytes([0x1b, 0x5b, 0x43])),
          divider(),
          key('Home', () => onWriteBytes([0x1b, 0x5b, 0x48])),
          key('End', () => onWriteBytes([0x1b, 0x5b, 0x46])),
          key('PgUp', () => onWriteBytes([0x1b, 0x5b, 0x35, 0x7e])),
          key('PgDn', () => onWriteBytes([0x1b, 0x5b, 0x36, 0x7e])),
          key('Del', () => onWriteBytes([0x1b, 0x5b, 0x33, 0x7e])),
          divider(),
          key('F1', () => onWriteBytes([0x1b, 0x4f, 0x50])),
          key('F2', () => onWriteBytes([0x1b, 0x4f, 0x51])),
          key('F3', () => onWriteBytes([0x1b, 0x4f, 0x52])),
          key('F4', () => onWriteBytes([0x1b, 0x4f, 0x53])),
          divider(),
          key('Paste', () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text;
            if (text == null) return;
            // Solo envuelve en bracketed paste (?2004) si el programa
            // remoto lo pidió; si no, aparecería "^[[200~" literal.
            if (bracketedPasteEnabled) onWrite('\x1b[200~');
            onWriteBytes(utf8.encode(text));
            if (bracketedPasteEnabled) onWrite('\x1b[201~');
          }),
          key('/', () => onWriteBytes([0x2f])),
          key('-', () => onWriteBytes([0x2d])),
          key('|', () => onWriteBytes([0x7c])),
        ],
      ),
    );
  }
}

/// Tecla con animación de presión (escala 0.92) y transición de color
/// animada para el estado activo/presionado (TER-13).
class _AnimatedKey extends StatefulWidget {
  const _AnimatedKey({
    required this.label,
    required this.onTap,
    required this.active,
    required this.keyBg,
    required this.keyFg,
    required this.accent,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color keyBg;
  final Color keyFg;
  final Color accent;

  @override
  State<_AnimatedKey> createState() => _AnimatedKeyState();
}

class _AnimatedKeyState extends State<_AnimatedKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active || _pressed;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? widget.accent.withValues(alpha: 0.16)
                : widget.keyBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? widget.accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10.5,
              letterSpacing: 0.4,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : widget.keyFg,
            ),
          ),
        ),
      ),
    );
  }
}
