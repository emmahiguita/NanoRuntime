import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart'
    show kNanoBarScrollReserve;
import 'package:nanoai/features/home/buho_wallpaper.dart';
import 'package:nanoai/features/terminal/terminal_core.dart';
import '../widgets/terminal_session_item.dart';
import '../widgets/terminal_top_bar.dart';
import '../widgets/terminal_height_resize_handle.dart';
import '../widgets/terminal_view_box.dart';

/// Pantalla principal de Terminal con arquitectura limpia y PTY POSIX.
///
/// QUÉ HACE:
/// Administra el ciclo de vida de múltiples sesiones interactivas,
/// desacoplando la presentación en componentes especializados de menos de 200 líneas.
///
/// CÓMO FUNCIONA:
/// Conecta el dock unificado con la sesión activa vía [NanoInputScope] e invoca
/// el intérprete PTY mediante GlobalKeys, asegurando la destrucción de procesos al cerrar pestañas.
///
/// POR QUÉ:
/// Garantiza principios SOLID, previene procesos zombie y mantiene alta mantenibilidad pedagógica.
class TerminalTabScreen extends StatefulWidget {
  final String? initialCommand;
  const TerminalTabScreen({super.key, this.initialCommand});

  @override
  State<TerminalTabScreen> createState() => _TerminalTabScreenState();
}

class _TerminalTabScreenState extends State<TerminalTabScreen>
    with WidgetsBindingObserver {
  int _active = 0;
  final _sessions = <TerminalSessionItem>[];
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
    final restored = <TerminalSessionItem>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('terminal_sessions');
      if (json != null) {
        final list = jsonDecode(json) as List;
        for (final s in list) {
          final m = s as Map<String, dynamic>;
          restored.add(
            TerminalSessionItem(
              id: m['id'],
              name: m['name'],
              cwd: m['cwd'],
              type: m['type'],
              color: _sessionColor(m['type']),
              key: GlobalKey<NanoTerminalState>(debugLabel: 't${m['id']}'),
            ),
          );
        }
      }
    } catch (_) {}

    if (restored.isEmpty) {
      restored.add(
        TerminalSessionItem(
          id: 0,
          name: 'bash',
          cwd: '/home/nanoai',
          type: 'bash',
          color: _sessionColor('bash'),
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
    final list = _sessions.map((s) => s.toJson()).toList();
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
      (s.key.currentState as NanoTerminalState?)?.handleLifecycleState(state);
    }
  }

  void _addNewTab() {
    final nextNum = _sessions.length + 1;
    final name = 'bash $nextNum';
    _sessions.add(
      TerminalSessionItem(
        id: _nextId,
        name: name,
        cwd: '/home/nanoai',
        type: 'bash',
        color: _sessionColor('bash'),
        key: GlobalKey<NanoTerminalState>(debugLabel: 't$_nextId'),
      ),
    );
    _nextId++;
    setState(() => _active = _sessions.length - 1);
  }

  void _closeTab(int id) {
    if (_sessions.length <= 1) return;
    setState(() {
      _sessions.removeWhere((s) => s.id == id);
      if (_active >= _sessions.length) _active = _sessions.length - 1;
    });
  }

  Color _sessionColor(String type) => switch (type) {
        'bash' => const Color(0xFF21F2B2),
        'python' => const Color(0xFF42D9FF),
        'node' => const Color(0xFF9B8AFF),
        'ssh' => const Color(0xFFC084FC),
        'docker' => const Color(0xFF6592FF),
        _ => const Color(0xFFFFA726),
      };

  @override
  Widget build(BuildContext context) {
    final themeColors = NanoThemeExtension.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chrome = isDark ? const Color(0xFF07192B) : themeColors.surface;
    final fg = isDark ? const Color(0xFF21F2B2) : themeColors.terminalGreen;

    return NanoInputScope(
      scopeId: 'terminal',
      controller: _commandController,
      focusNode: _commandFocusNode,
      keepFocusOnSubmit: true,
      keepDockVisible: true,
      hint: _sessions.isNotEmpty
          ? 'Comando para ${_sessions[_active].name}...'
          : 'Escribe un comando de terminal...',
      onSubmit: (text) {
        final trimmed = text.trim();
        if (trimmed.isNotEmpty &&
            _sessions.isNotEmpty &&
            _active >= 0 &&
            _active < _sessions.length) {
          final state =
              _sessions[_active].key.currentState as NanoTerminalState?;
          state?.executeCommand(trimmed);
          _commandController.clear();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape ||
                  constraints.maxHeight < 500;
          final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          final double bottomReserve = isKeyboardOpen
              ? 0.0
              : (isLandscape ? 64.0 : kNanoBarScrollReserve);

          final terminalBox = TerminalViewBox(
            sessions: _sessions,
            activeIndex: _active,
            isSquareMode: _isSquareMode,
            fgColor: fg,
            isDark: isDark,
            engine: _engine,
            commandFocusNode: _commandFocusNode,
            commandController: _commandController,
            initialCommand: widget.initialCommand,
            onTitleChanged: (i, title) {
              if (title != _sessions[i].name) {
                setState(() => _sessions[i].name = title);
              }
            },
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: BuhoWallpaper(scrimOpacity: isDark ? 0.72 : 0.52),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomReserve),
                  child: Column(
                    children: [
                      TerminalTopBar(
                        sessions: _sessions,
                        activeIndex: _active,
                        isSquareMode: _isSquareMode,
                        chromeColor: chrome,
                        fgColor: fg,
                        isDark: isDark,
                        onSelectTab: (idx) => setState(() => _active = idx),
                        onCloseTab: _closeTab,
                        onAddTab: _addNewTab,
                        onToggleSquare: () {
                          setState(() {
                            _isSquareMode = !_isSquareMode;
                            if (!_isSquareMode && _heightFraction < 0.65) {
                              _heightFraction = 0.85;
                            }
                          });
                        },
                      ),
                      TerminalHeightResizeHandle(
                        handleColor: fg,
                        onVerticalDragDelta: (delta) {
                          setState(() {
                            _isSquareMode = false;
                            final deltaFrac = delta / constraints.maxHeight;
                            _heightFraction = (_heightFraction - deltaFrac)
                                .clamp(0.35, 1.0);
                          });
                        },
                        onDoubleTap: () {
                          setState(() {
                            _heightFraction =
                                _heightFraction > 0.70 ? 0.45 : 0.95;
                          });
                        },
                      ),
                      if (_isSquareMode)
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                                aspectRatio: 1.0, child: terminalBox),
                          ),
                        )
                      else if (_heightFraction >= 0.98)
                        Expanded(child: terminalBox)
                      else ...[
                        Expanded(
                          flex: (_heightFraction * 100).round().clamp(20, 100),
                          child: terminalBox,
                        ),
                        Spacer(
                          flex: ((1.0 - _heightFraction) * 100)
                              .round()
                              .clamp(1, 80),
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
