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

    // Esta es la única superficie del chat. El presentador solo limita la
    // ventana y su teclado; no superpone otro fondo ni otro botón de cierre.
    return GlassSurface(
      height: height,
      radius: 24,
      interactive: false,
      padding: EdgeInsets.zero,
      child: _buildResponsiveBody(visual, entries),
    );
  }
}
