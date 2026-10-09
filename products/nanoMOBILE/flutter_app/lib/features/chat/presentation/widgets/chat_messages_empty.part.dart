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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompact = mediaSize.height < 600;
    final chatState = ref.watch(chatProvider);
    final isGenerating = chatState.generating;

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
                // Minimalist iOS Metallic Glass AI Core
                Container(
                  width: isCompact ? 64 : 80,
                  height: isCompact ? 64 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.glassPrimary.withValues(alpha: 0.85),
                        colors.glassSurface.withValues(alpha: 0.40),
                      ],
                    ),
                    border: Border.all(
                      color: isGenerating
                          ? colors.accent.withValues(alpha: 0.60)
                          : colors.onSurface.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isGenerating ? colors.accent : Colors.black)
                            .withValues(alpha: isGenerating ? 0.25 : 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: isCompact ? 30 : 38,
                      color: isGenerating ? colors.accent : colors.onSurface.withValues(alpha: 0.90),
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 14 : 20),
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

