part of 'conversation_detail_sheet.dart';

// Estado dueño de editores y solicitud de borrador; dispose libera ambos.
class _ConversationDetailSheetState
    extends ConsumerState<ConversationDetailSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isHumanOwned = false, _busy = false;
  bool _preferWebHistory = true;
  ExecutionBudget? _suggestionBudget;
  String? _statusText;
  List<String> _suggestions = const [];
  late ConversationAgentId _agentId;
  DeviceNotification? _activeNotification;
  List<ConversationMemoryEntry> _liveEntries = const [];
  DeviceNotification? _queuedHistoryNotification;
  bool _historyLoadInProgress = false, _historyReloadRequested = false;

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _isHumanOwned = widget.item.humanOwns;
    _agentId = widget.item.agentId;
    _restoreWhatsAppAutomation();
    if (widget.item.hasPendingReply && widget.item.pendingReplyText != null) {
      _inputController.text = widget.item.pendingReplyText!;
    }
    if (widget.item.pendingSuggestions.isNotEmpty) {
      _suggestions = widget.item.pendingSuggestions;
    }
    _loadLiveHistoryAndCapabilities();
  }

  @override
  void dispose() {
    // Cancela solamente la inferencia pedida por esta hoja, no la de otros chats.
    _suggestionBudget?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(conversationHubVersionProvider);
    // Sincronización reactiva inmediata con el tema global del sistema Nano AI.
    ref.watch(settingsProvider.select((s) => s.themeMode));

    // Un mensaje en otro chat no debe disparar IPC y reconstruir este historial.
    ref.listen(liveNotificationStreamProvider, (_, next) {
      final map = next.valueOrNull;
      if (map == null || map.isEmpty) return;
      final notification = DeviceNotification.fromMap(map);
      if (_notificationMatches(notification)) {
        _loadLiveHistoryAndCapabilities(observed: notification);
      }
    });

    final visual = AutomationVisual.of(context);
    final themeExt = NanoThemeExtension.of(context);
    final colors = visual.resolvedColors;
    final memoryStore = ref.watch(conversationMemoryStoreProvider);
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    final entries = ConversationHistoryResolver.resolve(
      item: widget.item,
      store: memoryStore,
      liveEntries: _liveEntries,
    );

    final height =
        (media.size.height - media.viewInsets.bottom) *
        (isLandscape ? 0.98 : 0.90);

    final blurSigma = themeExt.glassEnabled
        ? (themeExt.glassBlur * 1.3).clamp(14.0, 32.0)
        : 0.0;

    // Superficie Liquid Glass conectada orgánicamente al tema real del sistema.
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.glassBorder.withValues(
            alpha: visual.isDark ? 0.22 : 0.50,
          ),
          width: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: visual.shadow.withValues(alpha: visual.isDark ? 0.38 : 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Papel tapiz Doodle Nano Owl reactivo a modo oscuro y claro
              Positioned.fill(
                child: Image.asset(
                  visual.isDark
                      ? 'assets/automation/messaging_wallpaper_dark.jpg'
                      : 'assets/automation/messaging_wallpaper_light.jpg',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              // Velo de gradiente translúcido para alto contraste y legibilidad óptima
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.backgroundElevated.withValues(
                          alpha: visual.isDark ? 0.38 : 0.45,
                        ),
                        colors.backgroundPrimary.withValues(
                          alpha: visual.isDark ? 0.58 : 0.65,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildResponsiveBody(visual, entries),
            ],
          ),
        ),
      ),
    );
  }
}
