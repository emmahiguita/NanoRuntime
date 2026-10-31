part of 'chat_messages.dart';

/// Componente visual de texto en streaming con estela cromática activa (Color Trail).
///
/// **QUÉ HACE:**
/// Renderiza el texto en generación aplicando un degradado dinámico en los últimos
/// caracteres emitidos (estela cromática de `accent` / `primary` a `onSurface`).
///
/// **CÓMO FUNCIONA:**
/// Divide el texto entre el cuerpo asentado y la cola activa (~28 caracteres). La cola
/// interpola progresivamente color y resplandor hacia la vanguardia, rematando con el cursor.
/// Si detecta bloques de código complejos (```), conmuta a [MarkdownBody] para no romper la sintaxis.
///
/// **POR QUÉ:**
/// Traslada el patrón visual de `expo-animated-streaming-text` con rendimiento óptimo
/// en Flutter (60/120fps en Skia/Impeller) y respeto estricto a accesibilidad.
class NanoAnimatedStreamingText extends StatelessWidget {
  const NanoAnimatedStreamingText({
    super.key,
    required this.text,
    this.trailLength = 28,
  });

  final String text;
  final int trailLength;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Conmuta a Markdown completo si hay bloques de código o sintaxis compleja
    if (text.contains('```')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MarkdownBody(
            data: text,
            styleSheet: _buildChatMarkdownStyleSheet(context, isUser: false),
          ),
          const SizedBox(height: 6),
          const StreamingCursor(),
        ],
      );
    }

    final spans = _buildTrailSpans(context, colors, reduceMotion);

    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        height: 1.45,
        letterSpacing: -0.1,
        color: colors.onSurface,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  /// Construye los spans dividiendo entre texto asentado y estela cromática dinámica.
  List<InlineSpan> _buildTrailSpans(
    BuildContext context,
    NanoColors colors,
    bool reduceMotion,
  ) {
    if (text.isEmpty) {
      return const [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: StreamingCursor(),
        ),
      ];
    }

    // Modo accesible o sin animación: texto plano sin degradados ni sobrecarga
    if (reduceMotion || text.length <= 2) {
      return [
        TextSpan(text: text),
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.only(left: 3),
            child: StreamingCursor(),
          ),
        ),
      ];
    }

    final effectiveTrail = trailLength.clamp(4, text.length);
    final settledLength = text.length - effectiveTrail;
    final settledPart = text.substring(0, settledLength);
    final trailPart = text.substring(settledLength);

    final List<InlineSpan> result = [];

    // Texto asentado: parseo ligero de negritas inline (**texto**)
    if (settledPart.isNotEmpty) {
      result.addAll(_parseSettledSpans(settledPart, colors.onSurface));
    }

    // Estela cromática dinámica sobre los caracteres en generación activa
    final trailLen = trailPart.length;
    for (int i = 0; i < trailLen; i++) {
      final char = trailPart[i];
      final t = (i + 1) / trailLen; // Progresión 0.0 -> 1.0 hacia el cursor

      // Interpolación: onSurface (asentado) -> primary -> accent (vanguardia)
      final Color charColor;
      if (t < 0.45) {
        charColor = Color.lerp(colors.onSurface, colors.primary, t / 0.45)!;
      } else {
        charColor = Color.lerp(
          colors.primary,
          colors.accent,
          (t - 0.45) / 0.55,
        )!;
      }

      // Halo óptico sutil en los últimos caracteres generados
      final List<Shadow> shadows;
      if (t > 0.65) {
        final glowFactor = (t - 0.65) / 0.35;
        shadows = [
          Shadow(
            color: colors.accent.withValues(alpha: glowFactor * 0.55),
            blurRadius: 6 * glowFactor,
          ),
        ];
      } else {
        shadows = const [];
      }

      result.add(
        TextSpan(
          text: char,
          style: TextStyle(
            color: charColor,
            fontWeight: t > 0.75 ? FontWeight.w600 : FontWeight.w400,
            shadows: shadows,
          ),
        ),
      );
    }

    // Cursor fluido colocado exactamente al final del último caracter generado
    result.add(
      const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: EdgeInsets.only(left: 3),
          child: StreamingCursor(),
        ),
      ),
    );

    return result;
  }

  /// Parsea negritas inline (sintaxis `**`) para preservar formato en texto asentado.
  List<InlineSpan> _parseSettledSpans(String text, Color baseColor) {
    final List<InlineSpan> spans = [];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: baseColor),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(color: baseColor, fontWeight: FontWeight.w700),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: baseColor),
      ));
    }
    return spans;
  }
}
