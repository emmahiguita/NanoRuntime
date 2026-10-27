part of 'ansi_terminal.dart';

/// Componente ANSI: conserva el protocolo y separa su representación.
class AnsiTerminalView extends StatefulWidget {
  final AnsiTerminal terminal;
  final bool active;
  const AnsiTerminalView(this.terminal, {super.key, this.active = true});

  @override
  State<AnsiTerminalView> createState() => _AnsiTerminalViewState();
}
