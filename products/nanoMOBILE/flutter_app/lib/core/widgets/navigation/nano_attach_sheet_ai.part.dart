part of 'nano_attach_sheet.dart';

// nano_attach_sheet_ai.part.dart — Sección de asistentes y modelos de IA web.
// QUÉ HACE: Despliega cápsulas translúcidas para invocar ChatGPT, Gemini, DeepSeek o Claude.
// CÓMO FUNCIONA: Pastillas Liquid Glass discretas sin círculos chillones ni colores saturados.
// POR QUÉ: Extraído de nano_attach_sheet para cumplir SRP y cota de < 100 líneas.

/// Sección de selección de modelos IA web con diseño de pastillas iOS Liquid Glass.
class _AiInjectSection extends StatelessWidget {
  const _AiInjectSection();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _AiInjectTile(
        label: 'ChatGPT',
        command: '@chatgpt ',
        icon: CupertinoIcons.chat_bubble_2,
      ),
      _AiInjectTile(
        label: 'Gemini',
        command: '@gemini ',
        icon: CupertinoIcons.sparkles,
      ),
      _AiInjectTile(
        label: 'DeepSeek',
        command: '@deepseek ',
        icon: CupertinoIcons.compass,
      ),
      _AiInjectTile(
        label: 'Claude',
        command: '@claude ',
        icon: CupertinoIcons.lightbulb,
      ),
    ],
  );
}

/// Pastilla individual para activar un modelo web en el prompt.
class _AiInjectTile extends StatelessWidget {
  const _AiInjectTile({
    required this.label,
    required this.command,
    required this.icon,
  });

  final String label, command;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(command);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: isDark ? 0.07 : 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.18),
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.onSurfaceVariant, size: 13.5),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
