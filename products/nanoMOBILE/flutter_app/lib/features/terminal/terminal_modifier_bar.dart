import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  /// When false, clipboard text is sent raw (no ESC[200~/201~ wrappers).
  final bool bracketedPasteEnabled;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11,
      color: fg.withValues(alpha: 0.7),
    );

    Widget key(String label, VoidCallback onTap,
        {String? longLabel, bool active = false}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? fg.withValues(alpha: 0.16)
                : fg.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active
                  ? fg.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            longLabel ?? label,
            style: active
                ? style.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  )
                : style,
          ),
        ),
      );
    }

    return Container(
      color: chrome,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          key('Esc', () => onWriteBytes([0x1b])),
          key(
            'Ctrl',
            onToggleCtrl,
            longLabel: ctrlActive ? 'Ctrl ON' : 'Ctrl',
            active: ctrlActive,
          ),
          key('Tab', () => onWriteBytes([0x09])),
          // TER-11: señales accesibles en táctil (un tap, sin Ctrl fijo),
          // junto a Ctrl y SIEMPRE visibles (Wrap multi-línea — antes el
          // scroll horizontal las dejaba fuera de pantalla).
          // 0x03 por ISIG del kernel genera SIGINT al grupo foreground;
          // sin kill() desde la app (seccomp ColorOS hostil con syscalls
          // extra — precedente shmget→SIGSYS).
          key('C-c', () => onWriteBytes([0x03]), longLabel: 'Ctrl+C'),
          key('C-d', () => onWriteBytes([0x04]), longLabel: 'Ctrl+D'),
          key('C-z', () => onWriteBytes([0x1a]), longLabel: 'Ctrl+Z'),
          key('<', () => onWriteBytes([0x1b, 0x5b, 0x44])),
          key('v', () => onWriteBytes([0x1b, 0x5b, 0x42])),
          key('^', () => onWriteBytes([0x1b, 0x5b, 0x41])),
          key('>', () => onWriteBytes([0x1b, 0x5b, 0x43])),
          key('Home', () => onWriteBytes([0x1b, 0x5b, 0x48])),
          key('End', () => onWriteBytes([0x1b, 0x5b, 0x46])),
          key('PgUp', () => onWriteBytes([0x1b, 0x5b, 0x35, 0x7e])),
          key('PgDn', () => onWriteBytes([0x1b, 0x5b, 0x36, 0x7e])),
          key('Del', () => onWriteBytes([0x1b, 0x5b, 0x33, 0x7e])),
          key('F1', () => onWriteBytes([0x1b, 0x4f, 0x50])),
          key('F2', () => onWriteBytes([0x1b, 0x4f, 0x51])),
          key('F3', () => onWriteBytes([0x1b, 0x4f, 0x52])),
          key('F4', () => onWriteBytes([0x1b, 0x4f, 0x53])),
          key('Paste', () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text;
            if (text == null) return;
            // Only wrap in bracketed paste sequences when the remote program
            // has explicitly requested it via DECSET ?2004. Sending the
            // wrappers unconditionally causes literal "^[[200~" garbage to
            // appear in shells that have not enabled the mode.
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
