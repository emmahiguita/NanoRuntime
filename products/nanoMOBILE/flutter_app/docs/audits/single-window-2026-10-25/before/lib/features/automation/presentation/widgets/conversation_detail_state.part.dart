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
    // Un mensaje en otro chat no debe disparar IPC y reconstruir este historial.
    ref.listen(liveNotificationStreamProvider, (_, next) {
      final map = next.valueOrNull;
      if (map == null || map.isEmpty) return;
      final notification = DeviceNotification.fromMap(map);
      if (_notificationMatches(notification)) {
        // El evento ya trae sus mensajes: no vuelve a extraer 50 notificaciones.
        _loadLiveHistoryAndCapabilities(observed: notification);
      }
    });

    final visual = AutomationVisual.of(context);
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: visual.isDark
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.70),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: visual.isDark ? 0.55 : 0.20,
              ),
              blurRadius: 35,
              spreadRadius: -5,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AutomationBackdrop(
                      scrimOpacity: visual.isDark ? 0.20 : 0.32,
                    ),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: visual.isDark
                                ? [
                                    const Color(0xD90A0F1D),
                                    const Color(0xEB060A14),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.88),
                                    Colors.white.withValues(alpha: 0.94),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: RepaintBoundary(
                child: _buildResponsiveBody(visual, entries),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
