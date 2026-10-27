import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';
import '../widgets/terminal_command_bar.dart';
import '../widgets/terminal_package_dialog.dart';
import 'package:nanoai/features/terminal/terminal_core.dart';
import '../widgets/terminal_session_item.dart';
import '../widgets/terminal_top_bar.dart';
import '../widgets/terminal_view_box.dart';

part 'terminal_screen_sessions.dart';
part 'terminal_screen_layout.dart';

/// Terminal con sesiones PTY preservadas y un editor propio para la pestaña activa.
/// El padre conserva controladores y foco; el motor conserva ejecución e historial.
class TerminalTabScreen extends StatefulWidget {
  final String? initialCommand;
  const TerminalTabScreen({super.key, this.initialCommand});

  @override
  State<TerminalTabScreen> createState() => _TerminalTabScreenState();
}

class _TerminalTabScreenState extends State<TerminalTabScreen>
    with WidgetsBindingObserver {
  int _active = 0;
  bool _routeVisible = true;
  bool _foreground = true;
  bool _visibilityPending = false;
  final _sessions = <TerminalSessionItem>[];
  int _nextId = 0;
  late final LLMEngineClient _engine;

  final _commandController = TextEditingController();
  final _commandFocusNode = FocusNode();
  bool _isSquareMode = false;
  bool _directInput = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = LLMEngineClient();
    _restoreSessions();
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

  // Visibilidad de ruta, pestaña y aplicación deben cumplirse juntas.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible = TickerMode.of(context);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _scheduleVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncVisibility();
  }

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    _scheduleVisibility();
  }

  // Espera a que las GlobalKeys nuevas estén montadas antes de pausar/reanudar.
  void _scheduleVisibility() {
    if (_visibilityPending) return;
    _visibilityPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityPending = false;
      if (mounted) _syncVisibility();
    });
  }

  void _syncVisibility() {
    for (var i = 0; i < _sessions.length; i++) {
      (_sessions[i].key.currentState as NanoTerminalState?)
          ?.handleLifecycleState(
            _foreground && _routeVisible && i == _active
                ? AppLifecycleState.resumed
                : AppLifecycleState.hidden,
          );
    }
  }

  @override
  Widget build(BuildContext context) => _buildTerminalLayout(context);
}
