import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/features/terminal/terminal_core.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';

class TerminalTabScreen extends StatefulWidget {
  /// Comando que se ejecuta una sola vez en la sesión inicial cuando el
  /// shell está listo (ej: "kali shell" desde la card Kali del dashboard).
  final String? initialCommand;
  const TerminalTabScreen({super.key, this.initialCommand});
  @override
  State<TerminalTabScreen> createState() => _S();
}

class _S extends State<TerminalTabScreen> {
  int _active = 0;
  final _sessions = <_Sess>[];
  int _counter = 0;
  // ID de sesión monotónico: NUNCA _sessions.length (cerrar+añadir dejaba
  // ids duplicados que rompían ValueKey('t${s.id}') y _close removeWhere).
  int _nextId = 0;
  late final LLMEngineClient _engine;

  final _commandController = TextEditingController();
  final _commandFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _engine = LLMEngineClient();
    _restoreSessions();
  }

  Future<void> _restoreSessions() async {
    final restored = <_Sess>[];
    var restoredCounter = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('terminal_sessions');
      if (json != null) {
        final list = jsonDecode(json) as List;
        for (final s in list) {
          final m = s as Map<String, dynamic>;
          restored.add(
            _Sess(
              id: m['id'], 
              name: m['name'], 
              cwd: m['cwd'], 
              type: m['type'],
              key: GlobalKey<NanoTerminalState>(debugLabel: 't${m['id']}'),
            ),
          );
        }
        restoredCounter = restored.length;
      }
    } catch (_) {}

    if (restored.isEmpty) {
      restored.add(
        _Sess(
          id: 0, 
          name: 'bash', 
          cwd: '/home/nanoai', 
          type: 'bash',
          key: GlobalKey<NanoTerminalState>(debugLabel: 't0'),
        ),
      );
      restored.add(
        _Sess(
          id: 1,
          name: 'logs',
          cwd: '/home/nanoai/logs',
          type: 'logs',
          color: const Color(0xFFFFB74D),
          key: GlobalKey<NanoTerminalState>(debugLabel: 't1'),
        ),
      );
      restoredCounter = restored.length;
    }
    _nextId =
        restored.map((s) => s.id).fold(0, (max, id) => id > max ? id : max) + 1;

    if (!mounted) return;
    setState(() {
      _sessions
        ..clear()
        ..addAll(restored);
      _counter = restoredCounter;
      if (_active >= _sessions.length) _active = _sessions.length - 1;
      if (_active < 0) _active = 0;
    });
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _sessions
        .map((s) => {'id': s.id, 'name': s.name, 'cwd': s.cwd, 'type': s.type})
        .toList();
    prefs.setString('terminal_sessions', jsonEncode(list));
  }

  @override
  void dispose() {
    _saveSessions();
    _engine.dispose();
    _commandController.dispose();
    _commandFocusNode.dispose();
    super.dispose();
  }

  void _add() {
    final t = [
      'bash',
      'python',
      'node',
      'ssh',
      'docker',
      'logs',
    ][_counter++ % 6];
    _sessions.add(
      _Sess(
        id: _nextId,
        name: t,
        cwd: '/home/nanoai',
        type: t,
        color: _clr(t),
        key: GlobalKey<NanoTerminalState>(debugLabel: 't$_nextId'),
      ),
    );
    _nextId++;
    setState(() => _active = _sessions.length - 1);
  }

  void _close(int id) {
    if (_sessions.length <= 1) return;
    setState(() {
      _sessions.removeWhere((s) => s.id == id);
      if (_active >= _sessions.length) _active = _sessions.length - 1;
    });
  }

  Color _clr(String t) => switch (t) {
    'bash' => const Color(0xFF21F2B2),
    'python' => const Color(0xFF42D9FF),
    'node' => const Color(0xFF9B8AFF),
    'ssh' => const Color(0xFFC084FC),
    'docker' => const Color(0xFF6592FF),
    _ => const Color(0xFFFFA726),
  };

  @override
  Widget build(BuildContext context) {
    // Identidad universal Obsidian para terminal: el entorno hacker/PTY
    // es intrínsecamente oscuro y de alto contraste en cualquier modo.
    const bg = Color(0xFF020611);
    const chrome = Color(0xFF07192B);
    const fg = Color(0xFF21F2B2);

    return NanoInputScope(
      scopeId: 'terminal',
      controller: _commandController,
      focusNode: _commandFocusNode,
      keepFocusOnSubmit: true,
      hint: _sessions.isNotEmpty 
          ? 'Comando para ${_sessions[_active].name}...' 
          : 'Escribe un comando de terminal...',
      onSubmit: (text) {
        if (_sessions.isNotEmpty && _active >= 0 && _active < _sessions.length) {
          _sessions[_active].key.currentState?.executeCommand(text);
        }
      },
      child: Container(
        color: bg,
        child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Tab bar
            Container(
              height: 38,
              padding: const EdgeInsets.only(left: 4, right: 4),
              decoration: BoxDecoration(
                color: chrome,
                border: Border(
                  bottom: BorderSide(color: fg.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  // Retroceso: /terminal/shell es ruta empujada — sin esto no
                  // hay forma visible de volver (solo el gesto del sistema).
                  IconButton(
                    tooltip: 'Atrás',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    padding: const EdgeInsets.all(4),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded, size: 18, color: fg),
                  ),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < _sessions.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => _active = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(top: 4, right: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: i == _active ? bg : Colors.transparent,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                border: i == _active
                                    ? Border(
                                        top: BorderSide(
                                          color: _sessions[i].color ?? fg,
                                          width: 2,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _sessions[i].color ?? fg,
                                      shape: BoxShape.circle,
                                      boxShadow: i == _active
                                          ? [
                                              BoxShadow(
                                                color:
                                                    (_sessions[i].color ?? fg)
                                                        .withValues(alpha: 0.5),
                                                blurRadius: 4,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    _sessions[i].name,
                                    style: TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 11.5,
                                      fontWeight: i == _active
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: i == _active
                                          ? fg
                                          : fg.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  if (_sessions.length > 1) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _close(_sessions[i].id),
                                      child: Icon(
                                        Icons.close,
                                        size: 13,
                                        color: fg.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _add,
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: fg.withValues(alpha: 0.06),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 16,
                        color: fg.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Centro Terminal',
                    child: GestureDetector(
                      onTap: () => context.go('/terminal'),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: fg.withValues(alpha: 0.06),
                        ),
                        child: Icon(
                          Icons.apps_rounded,
                          size: 16,
                          color: fg.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Visor Linux',
                    child: GestureDetector(
                      onTap: () => context.push('/desktop'),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: fg.withValues(alpha: 0.06),
                        ),
                        child: Icon(
                          Icons.desktop_windows_rounded,
                          size: 16,
                          color: fg.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // IndexedStack mantiene vivas todas las sesiones — cambiar de tab
            // no mata el PTY ni pierde el estado del terminal.
            Expanded(
              child: IndexedStack(
                index: _active,
                children: [
                  for (final (i, s) in _sessions.indexed)
                    NanoTerminal(
                      key: s.key,
                      sessionId: s.id,
                      initialCwd: s.cwd,
                      engine: _engine,
                      visible: i == _active,
                      focusNode: i == _active ? _commandFocusNode : null,
                      commandController:
                          i == _active ? _commandController : null,
                      // Solo la primera sesión consume el comando inicial.
                      initialCommand: s.id == 0 ? widget.initialCommand : null,
                      onTitle: (title) {
                        if (title != s.name) setState(() => s.name = title);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _Sess {
  final int id;
  String name;
  final String cwd, type;
  final Color? color;
  final GlobalKey<NanoTerminalState> key;
  _Sess({
    required this.id,
    required this.name,
    required this.cwd,
    required this.type,
    this.color,
    required this.key,
  });
}
