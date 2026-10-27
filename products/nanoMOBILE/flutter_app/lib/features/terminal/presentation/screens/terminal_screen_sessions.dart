part of 'terminal_screen.dart';

/// Restaura metadatos y modifica pestañas sin cambiar la identidad del PTY activo.
extension _TerminalSessions on _TerminalTabScreenState {
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
    _update(() {
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

  void _addNewTab() {
    if (_sessions.length >= 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo de 16 sesiones de terminal.')),
      );
      return;
    }
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
    _update(() => _active = _sessions.length - 1);
  }

  void _closeTab(int id) {
    if (_sessions.length <= 1) return;
    _update(() {
      // Conserva la sesión por identidad aunque cambie de posición.
      final activeId = _sessions[_active].id;
      _sessions.removeWhere((s) => s.id == id);
      final preserved = _sessions.indexWhere((s) => s.id == activeId);
      _active = preserved >= 0
          ? preserved
          : _active.clamp(0, _sessions.length - 1);
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
}
