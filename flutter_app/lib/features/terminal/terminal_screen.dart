import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_tokens.dart';
import 'terminal_core.dart';

class TerminalTabScreen extends StatefulWidget { const TerminalTabScreen({super.key}); @override State<TerminalTabScreen> createState() => _S(); }

class _S extends State<TerminalTabScreen> {
  int _active = 0; final _sessions = <_Sess>[]; int _counter = 0;

  @override void initState() {
    super.initState();
    _sessions.add(_Sess(id: 0, name: 'bash', cwd: '/home/nanoai', type: 'bash'));
    _sessions.add(_Sess(id: 1, name: 'logs', cwd: '/home/nanoai/logs', type: 'logs', color: const Color(0xFFFFB74D)));
  }

  void _add() { final t = ['bash','python','node','ssh','docker','logs'][_counter++ % 6]; _sessions.add(_Sess(id: _sessions.length, name: t, cwd: '/home/nanoai', type: t, color: _clr(t))); setState(() => _active = _sessions.length - 1); }
  void _close(int id) { if (_sessions.length <= 1) return; setState(() { _sessions.removeWhere((s) => s.id == id); if (_active >= _sessions.length) _active = _sessions.length - 1; }); }
  Color _clr(String t) => switch (t) { 'bash' => const Color(0xFF00E676), 'python' => const Color(0xFF38BDF8), 'node' => const Color(0xFF8BC34A), 'ssh' => const Color(0xFFC084FC), 'docker' => const Color(0xFF0EA5E9), _ => const Color(0xFFFFB74D) };

  @override Widget build(BuildContext context) {
    final c = NanoThemeExtension.of(context).colors; final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF02040A) : const Color(0xFFF0F0F5);
    final chrome = dark ? const Color(0xFF0A0F1A) : const Color(0xFFE0E0EC);
    final fg = c.terminalGreen; final s = _sessions[_active];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(bottom: false, child: Column(children: [
        // Tab bar
        Container(height: 38, padding: const EdgeInsets.only(left: 4, right: 4), decoration: BoxDecoration(color: chrome, border: Border(bottom: BorderSide(color: fg.withValues(alpha: 0.08)))), child: Row(children: [
          Expanded(child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < _sessions.length; i++)
              GestureDetector(onTap: () => setState(() => _active = i), child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(top: 4, right: 2), padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: i == _active ? bg : Colors.transparent, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), border: i == _active ? Border(top: BorderSide(color: _sessions[i].color ?? fg, width: 2)) : null),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: _sessions[i].color ?? fg, shape: BoxShape.circle, boxShadow: i == _active ? [BoxShadow(color: (_sessions[i].color ?? fg).withValues(alpha: 0.5), blurRadius: 4)] : null)),
                  const SizedBox(width: 7),
                  Text(_sessions[i].name, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: i == _active ? FontWeight.w600 : FontWeight.w400, color: i == _active ? fg : fg.withValues(alpha: 0.45))),
                  if (_sessions.length > 1) ...[const SizedBox(width: 6), GestureDetector(onTap: () => _close(_sessions[i].id), child: Icon(Icons.close, size: 13, color: fg.withValues(alpha: 0.35)))],
                ]),
              )),
          ])),
          GestureDetector(onTap: _add, child: Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: fg.withValues(alpha: 0.06)), child: Icon(Icons.add, size: 16, color: fg.withValues(alpha: 0.5)))),
        ])),
        Expanded(child: NanoTerminal(key: ValueKey('t${s.id}'), sessionId: s.id, initialCwd: s.cwd)),
      ])),
    );
  }
}

class _Sess { final int id; final String name, cwd, type; final Color? color; _Sess({required this.id, required this.name, required this.cwd, required this.type, this.color}); }
