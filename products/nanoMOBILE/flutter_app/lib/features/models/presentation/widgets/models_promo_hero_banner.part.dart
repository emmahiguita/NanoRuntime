// models_promo_hero_banner.part.dart — Elementos visuales y frases del carrusel publicitario.
// QUÉ HACE: Provee el catálogo de frases, indicadores tipo Stories y shaders (< 180 líneas).
// CÓMO FUNCIONA: Micro-animaciones desacopladas con degradados de alto contraste.
part of 'models_promo_hero_banner.dart';

class PromoPhraseItem {
  final String tag, title, subtitle;
  final Color accentColor;
  const PromoPhraseItem({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
}

const List<PromoPhraseItem> kPromoPhrases = [
  PromoPhraseItem(
    tag: 'NANO AI • MOTOR LOCAL & RAG',
    title: 'Nano AI',
    subtitle: 'Automatiza, responde y organiza con inteligencia real.',
    accentColor: Color(0xFF38BDF8),
  ),
  PromoPhraseItem(
    tag: 'PRIVACIDAD • 100% OFFLINE',
    title: 'Privacidad Total',
    subtitle: 'Tus datos nunca salen del teléfono. Inferencia sin nube.',
    accentColor: Color(0xFF34D399),
  ),
  PromoPhraseItem(
    tag: 'AGENTES • MULTIMODAL',
    title: 'Asistente Autónomo',
    subtitle: 'Conexión fluida con mensajería, terminal y herramientas.',
    accentColor: Color(0xFFA78BFA),
  ),
  PromoPhraseItem(
    tag: 'BÚHO CÓSMICO • IDENTIDAD',
    title: 'Infinito por dentro',
    subtitle: 'Pequeño por fuera, infinito por dentro. La IA que vive contigo.',
    accentColor: Color(0xFFF472B6),
  ),
];

Widget buildCosmicGlassScaffold(bool isDark) {
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 0.8, sigmaY: 0.8),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.60, 1.0],
          colors: [
            (isDark ? const Color(0xFF070B19) : const Color(0xFF0F172A))
                .withValues(alpha: 0.94),
            (isDark ? const Color(0xFF0C1428) : const Color(0xFF1E293B))
                .withValues(alpha: 0.72),
            Colors.transparent,
          ],
        ),
      ),
    ),
  );
}

Widget buildPromoBadge(PromoPhraseItem phrase) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: phrase.accentColor.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: phrase.accentColor.withValues(alpha: 0.50), width: 0.8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: phrase.accentColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          phrase.tag,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: phrase.accentColor,
          ),
        ),
      ],
    ),
  );
}

Widget buildProgressDots({
  required int currentIndex,
  required double currentProgress,
  required ValueChanged<int> onDotTapped,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(kPromoPhrases.length, (i) {
      final isCurrent = i == currentIndex;
      final fill = isCurrent ? currentProgress : (i < currentIndex ? 1.0 : 0.0);
      return GestureDetector(
        onTap: () => onDotTapped(i),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 4),
          child: Container(
            width: isCurrent ? 18 : 6,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: fill,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }),
  );
}

Widget buildGlowingTitle(String text, double shimmerPos, Color accent) {
  return ShaderMask(
    shaderCallback: (bounds) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [
          (shimmerPos - 0.25).clamp(0.0, 1.0),
          shimmerPos.clamp(0.0, 1.0),
          (shimmerPos + 0.25).clamp(0.0, 1.0),
        ],
        colors: [const Color(0xFFFFFFFF), accent, const Color(0xFFDDD6FE)],
      ).createShader(bounds);
    },
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: Colors.white,
        shadows: [Shadow(color: accent.withValues(alpha: 0.80), blurRadius: 16)],
      ),
    ),
  );
}

Widget buildSubtitle(String subtitle) {
  return SizedBox(
    width: 230,
    child: Text(
      subtitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11.5,
        height: 1.30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: Color(0xFFF1F5F9),
        shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1))],
      ),
    ),
  );
}
