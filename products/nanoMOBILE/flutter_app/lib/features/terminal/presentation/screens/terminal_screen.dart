import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/widgets/nano_owl_avatar.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart'
    show kNanoBarScrollReserve;
import 'package:nanoai/features/home/buho_wallpaper.dart';
import 'package:nanoai/features/terminal/terminal_core.dart';

class TerminalTabScreen extends StatefulWidget {
  /// Comando que se ejecuta una sola vez en la sesión inicial cuando el
  /// shell está listo (ej: "kali shell" desde la card Kali del dashboard).
  final String? initialCommand;
  const TerminalTabScreen({super.key, this.initialCommand});
  @override
  State<TerminalTabScreen> createState() => _S();
}

class _S extends State<TerminalTabScreen> with WidgetsBindingObserver {
  int _active = 0;
  final _sessions = <_Sess>[];
  // ID de sesión monotónico: NUNCA _sessions.length (cerrar+añadir dejaba
  // ids duplicados que rompían ValueKey('t${s.id}') y _close removeWhere).
  int _nextId = 0;
  late final LLMEngineClient _engine;

  final _commandController = TextEditingController();
  final _commandFocusNode = FocusNode();
  double _heightFraction = 1.0;
  bool _isSquareMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = LLMEngineClient();
    _restoreSessions();
  }

  Future<void> _restoreSessions() async {
    final restored = <_Sess>[];
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
    }
    _nextId =
        restored.map((s) => s.id).fold(0, (max, id) => id > max ? id : max) + 1;

    if (!mounted) return;
    setState(() {
      _sessions
        ..clear()
        ..addAll(restored);
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
    WidgetsBinding.instance.removeObserver(this);
    _saveSessions();
    _engine.dispose();
    _commandController.dispose();
    _commandFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    for (final s in _sessions) {
      s.key.currentState?.handleLifecycleState(state);
    }
  }

  void _add() {
    final nextNum = _sessions.length + 1;
    final name = 'bash $nextNum';
    _sessions.add(
      _Sess(
        id: _nextId,
        name: name,
        cwd: '/home/nanoai',
        type: 'bash',
        color: _clr('bash'),
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
    // Identidad Obsidian para terminal: fondo oscuro de alto contraste
    // derivado de NanoThemeExtension respetando el tema de la app.
    final themeColors = NanoThemeExtension.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chrome = isDark ? const Color(0xFF07192B) : themeColors.surface;
    final fg = isDark ? const Color(0xFF21F2B2) : themeColors.terminalGreen;

    return NanoInputScope(
      scopeId: 'terminal',
      controller: _commandController,
      focusNode: _commandFocusNode,
      keepFocusOnSubmit: true,
      hint: _sessions.isNotEmpty 
          ? 'Comando para ${_sessions[_active].name}...' 
          : 'Escribe un comando de terminal...',
      onSubmit: (text) {
        final trimmed = text.trim();
        if (trimmed.isNotEmpty &&
            _sessions.isNotEmpty &&
            _active >= 0 &&
            _active < _sessions.length) {
          _sessions[_active].key.currentState?.executeCommand(trimmed);
          _commandController.clear();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDeviceLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final isLandscape = isDeviceLandscape && constraints.maxHeight < 520;
          final viewInsets = MediaQuery.viewInsetsOf(context);
          final isKeyboardOpen = viewInsets.bottom > 0;
          final double bottomReserve =
              isKeyboardOpen ? (isLandscape ? 56.0 : 72.0) : (isLandscape ? 90.0 : kNanoBarScrollReserve);

          final terminalContent = Container(
            margin: const EdgeInsets.fromLTRB(6, 2, 6, 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF020611).withValues(alpha: 0.90)
                  : themeColors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSquareMode
                    ? (_sessions.isNotEmpty ? (_sessions[_active].color ?? fg) : fg)
                    : fg.withValues(alpha: 0.14),
                width: _isSquareMode ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
                if (_isSquareMode)
                  BoxShadow(
                    color: (_sessions.isNotEmpty ? (_sessions[_active].color ?? fg) : fg)
                        .withValues(alpha: 0.18),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
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
                      initialCommand: i == _active ? widget.initialCommand : null,
                      onTitle: (title) {
                        if (title != s.name) setState(() => s.name = title);
                      },
                    ),
                ],
              ),
            ),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: BuhoWallpaper(
                    scrimOpacity: isDark ? 0.72 : 0.52,
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomReserve),
                  child: Column(
                    children: [
                      // Tab bar & control bar
                      Container(
                        height: 40,
                        padding: const EdgeInsets.only(left: 4, right: 4),
                        decoration: BoxDecoration(
                          color: chrome.withValues(alpha: isDark ? 0.82 : 0.90),
                          border: Border(
                            bottom: BorderSide(color: fg.withValues(alpha: 0.12)),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Retroceso: /terminal/shell es ruta empujada
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
                            const SizedBox(width: 2),
                            const NanoOwlAvatar(
                              size: 26,
                              state: NanoOwlState.idle,
                            ),
                            const SizedBox(width: 4),
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
                                          color: i == _active
                                              ? (isDark
                                                  ? const Color(0xFF030712).withValues(alpha: 0.92)
                                                  : themeColors.surface)
                                              : Colors.transparent,
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
                            // Botón de alternar Cuadro Geométrico Perfecto (1:1)
                            Semantics(
                              label: _isSquareMode ? 'Modo expandido' : 'Cuadro Geométrico (1:1)',
                              button: true,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isSquareMode = !_isSquareMode;
                                    if (!_isSquareMode && _heightFraction < 0.65) {
                                      _heightFraction = 0.85;
                                    }
                                  });
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(right: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: _isSquareMode
                                        ? fg.withValues(alpha: 0.20)
                                        : fg.withValues(alpha: 0.06),
                                    border: _isSquareMode
                                        ? Border.all(color: fg.withValues(alpha: 0.5), width: 1)
                                        : null,
                                  ),
                                  child: Icon(
                                    _isSquareMode ? Icons.crop_square_rounded : Icons.aspect_ratio_rounded,
                                    size: 16,
                                    color: _isSquareMode ? fg : fg.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
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
                            Semantics(
                              label: 'Centro Terminal',
                              button: true,
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
                            Semantics(
                              label: 'Visor Linux',
                              button: true,
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
                      // Barra interactiva de arrastre para subir y bajar la terminal libremente
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            _isSquareMode = false;
                            final deltaFraction = details.primaryDelta! / constraints.maxHeight;
                            // Arrastrar hacia arriba expande / sube la terminal, hacia abajo la reduce
                            _heightFraction = (_heightFraction - deltaFraction).clamp(0.35, 1.0);
                          });
                        },
                        onDoubleTap: () {
                          setState(() {
                            // Doble toque alterna entre altura media y altura completa
                            _heightFraction = _heightFraction > 0.70 ? 0.45 : 0.95;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: fg.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Contenedor de la terminal: modo cuadrado simétrico o altura regulable
                      if (_isSquareMode)
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: terminalContent,
                            ),
                          ),
                        )
                      else if (_heightFraction >= 0.98)
                        Expanded(
                          child: terminalContent,
                        )
                      else ...[
                        Expanded(
                          flex: (_heightFraction * 100).round().clamp(20, 100),
                          child: terminalContent,
                        ),
                        Spacer(
                          flex: ((1.0 - _heightFraction) * 100).round().clamp(1, 80),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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
