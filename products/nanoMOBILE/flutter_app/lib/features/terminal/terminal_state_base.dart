part of 'terminal_core.dart';

/// Dueño de recursos por sesión: los componentes prestan estas dependencias.
abstract class _TerminalStateBase extends State<NanoTerminal>
    implements _TerminalOperations {
  TerminalDependencies get _deps =>
      widget.deps ?? TerminalDependencies.instance;

  IBinExecutor? get _shell => _deps.shell;

  RootfsManager? get _rootfs => _deps.rootfs;

  ProotManager? get _proot => _deps.proot;

  KaliManager? get _kali => _deps.kali;

  DockerManager? get _docker => _deps.docker;

  LinuxDistribution? get _ubuntu => _deps.ubuntu;

  /// TerminalServices para plugins (DIP). Cached to avoid re-allocation on
  /// every plugin call — the closures capture `this` so the instance stays
  /// valid for the widget's lifetime.
  late final TerminalServices _services = TerminalServices(
    ctx: _ctx,
    out: _out,
    after: _after,
    rootfsEnv: _deps.rootfsEnv,
    getEngine: () => _engine,
    audit: (cmd, tag, data) {},
    getShell: () => _shell,
    getRootfs: () => _rootfs,
    getDocker: () => _docker,
    getKali: () => _kali,
    getProot: () => _proot,
    getUbuntu: () => _ubuntu,
    openPty: (argv, {env, ldPreload}) =>
        _ptyOpen(argv, env: env, ldPreload: ldPreload),
    deviceId: _devId,
    onClear: () {
      if (mounted) _controller.clear();
    },
    onNavigate: (route) {
      if (!mounted) return;
      try {
        context.push(route);
      } catch (_) {
        Navigator.of(context).pushNamed(route);
      }
    },
    mounted: mounted,
  );

  final HardwareInfoService _hw = HardwareInfoService();

  Map<String, dynamic>? get _devId => _hw.deviceId;

  FocusNode get _fn => widget.focusNode ?? _localFn;

  TextEditingController get _in => widget.commandController ?? _localIn;

  late final FocusNode _localFn = FocusNode();

  late final TextEditingController _localIn = TextEditingController();

  final ScrollController _sc = ScrollController();

  final _controller = TerminalSessionController();

  List<TL> get _lines => _controller.lines;

  final _hist = <String>[], _timers = <Timer>[];

  final _ctx = TerminalCtx();

  final _hIdx = Ref<int>(-1);

  bool _ctrl = false, _alive = true;

  bool _initialCmdDone = false;

  LLMEngineClient? _engine;

  PtySession? _pty;

  final _ptyLines = <String>[];

  AnsiTerminal? _ansi;

  CronScheduler? _cron;

  final _cmds = <String, CmdFn>{};

  CommandDispatcher? _dispatcher;

  PtyManager? _ptyManager;

  String get _baseDir {
    final usr = _shell?.usrDir ?? _rootfs?.usrDir ?? '';
    return usr.endsWith('/usr') ? usr.substring(0, usr.length - 4) : usr;
  }

  String get _usrDir => _shell?.usrDir ?? _rootfs?.usrDir ?? '';

  final _bashCwd = Ref<String>('/');

  /// Fallback dart:io real (ver real_fs_shell.dart). Solo se usa en hosts sin
  /// binarios Android (desktop/tests): los comandos FS operan sobre el
  /// filesystem real del host bajo un raíz sandbox. En Android manda el motor
  /// NanoRuntime (BusyBox vía Nanoshell FFI / rootfs).
  late final RealFsShell _realFs;

  /// Whitelist de comandos con ejecución real vía BusyBox (ver realCommands
  /// en terminal_types.dart). En hosts sin binarios Android, RealFsShell
  /// implementa el subconjunto dart:io como fallback real.
  String get _ps1 {
    final h = _devId?['hostname'] as String? ?? 'oppo';
    String home = _bashCwd.value;
    if (home == '/systemTemp/nano_real_root' || home == '/') {
      home = '~';
    } else if (home.startsWith('/systemTemp/nano_real_root/')) {
      home = home.substring('/systemTemp/nano_real_root'.length);
    }
    return 'nanoai@$h:$home\$ ';
  }

  bool _scrollPending = false;

  bool _autoPtyDone = false;

  bool get _ptyActive => _pty != null && !_pty!.isClosed;

  int _ptyRows = 24, _ptyCols = 80;

  /// Persistencia Noar (librería de comandos). SRP: la lógica vive en
  /// [NoarPersistence]; este campo es la instancia que la UI lee.
  final NoarPersistence _noar = NoarPersistence();

  List<Map<String, dynamic>> get _noarLib => _noar.entries;
}
