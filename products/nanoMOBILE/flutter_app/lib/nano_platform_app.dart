part of 'main.dart';

// Raíz visual y ciclo de vida UI; main conserva el arranque visible/headless.
class NanoPlatformApp extends ConsumerStatefulWidget {
  const NanoPlatformApp({super.key});

  @override
  ConsumerState<NanoPlatformApp> createState() => _NanoPlatformAppState();
}

class _NanoPlatformAppState extends ConsumerState<NanoPlatformApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onExternalPromptReceived = (prompt) {
      AppRouter.router.go('/chat');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // El callback puede ejecutarse después de cerrar esta raíz UI.
        if (!mounted) return;
        ref.read(chatProvider.notifier).send(prompt);
      });
    };
    // Habilitar inmersión total sticky: oculta la barra de estado (wifi, hora,
    // batería) para aprovechar al 100% la pantalla sin barras del sistema.
    _applyImmersiveMode();
    // Cargar settings persistidos (tema, password VNC, límites del motor)
    // ANTES del primer frame. Sin esto, un arranque en frío ignora el
    // password VNC guardado y el visor/launcher arrancan Xvnc sin auth.
    unawaited(ref.read(settingsProvider.notifier).init());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No usa Ref ni inicia servicios de una pantalla ya desmontada.
      if (!mounted) return;
      _applyImmersiveMode();
      unawaited(BootOrchestrator().run());
      // Pide los permisos runtime que falten (micrófono, medios y, en Android
      // 13+, POST_NOTIFICATIONS) tras el primer frame. Solo muestra diálogos de
      // los que faltan; los ya concedidos no molestan.
      unawaited(NanoRuntimeApi.instance.requestRuntimePermissions());
      // WA-UI-LIFECYCLE-01 — bootstrap del router de eventos y scheduler
      // mientras Nano esté abierta en foreground (UI path).
      ref.read(notificationEventRouterProvider);
      ref.read(timeTickSchedulerProvider);
    });
  }

  @override
  void dispose() {
    _onExternalPromptReceived = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyImmersiveMode();
      // Recupera mensajes durables al volver a la app sin esperar el ticker de 20 s.
      ref.read(notificationEventRouterProvider).drainPendingEvents();
    }
  }

  void _applyImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    final darkColors =
        (settings.themeMode == 'Grisáceo' || settings.themeMode == 'Opaco')
        ? NanoSpaceGrayColors()
        : NanoDarkColors();

    final lightColors = (settings.themeMode == 'Sistema')
        ? NanoSystemLightColors()
        : NanoLightColors();

    final lightTheme = AppTheme.buildTheme(
      lightColors,
      glassEnabled: settings.glassEnabled,
      glassOpacity: settings.glassOpacity,
      glassClarity: settings.glassClarity,
      glassBlur: settings.glassBlur,
    );

    final darkTheme = AppTheme.buildTheme(
      darkColors,
      glassEnabled: settings.glassEnabled,
      glassOpacity: settings.glassOpacity,
      glassClarity: settings.glassClarity,
      glassBlur: settings.glassBlur,
    );

    // Sin wrapper de orientación aquí: rotar forzaba rebuild del MaterialApp
    // completo y producía flicker ("pantalla dañada al voltearse"). La
    // orientación se resuelve DENTRO de cada pantalla vía LayoutBuilder/
    // MediaQuery, que ya manejan portrait/landscape con su propio layout.
    return MaterialApp.router(
      title: 'NanoPlatform',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      // TEMA REACTIVO: Sincronizado reactivamente con las preferencias del usuario (Claro / Oscuro / Sistema).
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : NanoMotionDurations.standard,
      themeAnimationCurve: NanoMotionCurves.standardDecel,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        // Las vistas flotantes están fuera del Navigator: necesitan su Overlay.
        // wrap actualiza el hijo y libera la entrada al desmontar; initialEntries
        // solo se lee al crear el estado y dejaba contenido obsoleto al reconstruir.
        return Material(
          type: MaterialType.transparency,
          child: Overlay.wrap(
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                const BrowserPipOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }
}
