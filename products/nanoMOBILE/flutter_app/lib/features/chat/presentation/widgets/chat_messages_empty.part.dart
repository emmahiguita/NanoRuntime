part of 'chat_messages.dart';

class EmptyChat extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompact = mediaSize.height < 600;

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
                // Animated Nano Owl Hero Avatar
                NanoOwlAvatar(
                  size: isCompact ? 72 : 96,
                  state: NanoOwlState.idle,
                  enableBreathing: true,
                  enableRandomBlink: true,
                  enableGlow: true,
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
