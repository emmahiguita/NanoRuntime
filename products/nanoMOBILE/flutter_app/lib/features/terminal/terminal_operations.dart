part of 'terminal_core.dart';

/// Contratos del único estado propietario; las implementaciones documentan cada operación.
abstract interface class _TerminalOperations {
  void _out(String t, Ln ty);
  void _after(Duration d, VoidCallback cb);
  void initState();
  void handleLifecycleState(AppLifecycleState state);
  void didUpdateWidget(covariant NanoTerminal oldWidget);

  void _autoOpenBash();
  void dispose();

  Future<void> _fetchDeviceIdentity();

  Future<double?> _readCpuTemp();

  Future<void> _initShell();
  void _buildRegistry();
  void _registerDiagnostics();
  void _registerGpu();
  void _registerInference();
  void _registerTuning();
  List<String> _tok(String c);

  bool _hasShellOps(String cmd);

  void _useCommand(String cmd);

  Future<void> executeCommand(String cmd);

  CmdExecCtx _execCtx();

  void _applyPtySize(double w, double h);

  Future<void> _ptyOpen(
    List<String> argv, {
    Map<String, String>? env,
    String? ldPreload,
    void Function(String, Ln)? o,
  });
  Future<void> _ptyClose({bool notify = true});

  bool _onKey(KeyEvent e);
  Future<void> _loadHistory();
  Future<void> _saveHistory();
  void openCommandLibrary();
  Widget build(BuildContext context);
}
