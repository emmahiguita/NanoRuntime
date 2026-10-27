part of 'terminal_core.dart';

/// Componente history: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalHistory on _TerminalStateBase {
  @override
  Future<void> _loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final j = p.getString('term_hist_${widget.sessionId}');
      if (j != null) _hist.addAll((jsonDecode(j) as List).cast<String>());
    } catch (_) {}
  }

  @override
  Future<void> _saveHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        'term_hist_${widget.sessionId}',
        jsonEncode(
          _hist.length > 500 ? _hist.sublist(_hist.length - 500) : _hist,
        ),
      );
    } catch (_) {}
  }

  /// Abre los comandos guardados por petición explícita, sin flotante ni temporizador.
  @override
  void openCommandLibrary() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoarPanel(
        library: _noarLib,
        fg: scheme.onSurface,
        dark: scheme.brightness == Brightness.dark,
        onUse: _useCommand,
      ),
    );
  }
}
