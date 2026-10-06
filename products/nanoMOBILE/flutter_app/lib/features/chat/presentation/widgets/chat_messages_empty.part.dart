part of 'chat_messages.dart';

class EmptyChat extends ConsumerWidget {
  const EmptyChat({
    super.key,
    required this.engineOnline,
    required this.hasModel,
    required this.onSuggestion,
    required this.onRetry,
    required this.onGoModels,
  });

  final bool engineOnline;
  final bool hasModel;
  final void Function(String) onSuggestion;
  final VoidCallback onRetry;
  final VoidCallback onGoModels;

  /// Mapea el estado del chatProvider a un NanoOwlState visual.
  NanoOwlState _owlState(ChatState chat) {
    if (chat.generating) return NanoOwlState.thinking;
    if (!chat.engineOnline) return NanoOwlState.sleep;
    if (chat.activeModelPath == null) return NanoOwlState.idle;
    if (chat.connection == ModelConnectionState.loadingModel) {
      return NanoOwlState.responding;
    }
    return NanoOwlState.idle;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompact = mediaSize.height < 600;
    final chatState = ref.watch(chatProvider);
    final owlState = _owlState(chatState);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isCompact ? 12 : 28,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Nano Owl Hero Avatar — sincronizado con chatProvider
                NanoOwlAvatar(
                  size: isCompact ? 72 : 96,
                  state: owlState,
                  enableBreathing: true,
                  enableRandomBlink: owlState == NanoOwlState.idle,
                  enableGlow: owlState != NanoOwlState.idle,
                ),
                SizedBox(height: isCompact ? 12 : 18),
                Text(
                  'Nano AI Assistant',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.onSurface,
                    fontSize: isCompact ? 20 : 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Inteligencia On-Device Soberana · Privada · Conectada al Hardware',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.onSurface.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                _EmptyChatEngineStatus(
                  engineOnline: engineOnline,
                  hasModel: hasModel,
                  onRetry: onRetry,
                  onGoModels: onGoModels,
                  onSuggestion: onSuggestion,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

