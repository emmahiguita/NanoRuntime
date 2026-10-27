import 'package:flutter/material.dart';
import '../../../../core/services/ambient_context_service.dart';

class NanoWeatherData {
  const NanoWeatherData({
    required this.temperature,
    required this.condition,
    required this.humidity,
    this.location,
    this.observedAt,
    this.consultedAt,
  });

  final String temperature;
  final String condition;
  final String humidity;
  final String? location;
  final String? observedAt;
  final DateTime? consultedAt;

  factory NanoWeatherData.fromAmbient(AmbientContext context) {
    final temperature = RegExp(
      r'-?\d{1,2}(?:[\.,]\d+)?\s*°\s*[cC]',
    ).firstMatch(context.weather)?.group(0)?.replaceAll(' ', '');
    final humidity = RegExp(
      r'\d{1,3}\s*%',
    ).firstMatch(context.weather)?.group(0)?.replaceAll(' ', '');
    final condition = context.weather.split(';').first.trim();
    return NanoWeatherData(
      temperature: temperature ?? '—',
      condition: condition,
      humidity: humidity == null ? 'Humedad —' : 'Humedad $humidity',
      location: context.providerArea.isEmpty
          ? context.location
          : context.providerArea,
      observedAt: context.observationTime,
      consultedAt: context.lastUpdated,
    );
  }
}

/// Resumen meteorológico compacto, construido solo con datos presentes en la
/// respuesta. Nunca completa cifras ausentes con valores de ejemplo.
class NanoRichWeatherCard extends StatelessWidget {
  const NanoRichWeatherCard({super.key, required this.data});

  final NanoWeatherData data;

  static NanoWeatherData? parse(String text) {
    final lower = text.toLowerCase();
    final isWeather =
        lower.contains('clima') ||
        lower.contains('temperatura') ||
        lower.contains('lluvia') ||
        lower.contains('humedad');
    if (!isWeather) return null;

    final temperature = RegExp(
      r'-?\d{1,2}(?:[\.,]\d+)?\s*°\s*[cC]',
    ).firstMatch(text)?.group(0)?.replaceAll(' ', '');
    final humidity = RegExp(
      r'\d{1,3}\s*%',
    ).firstMatch(text)?.group(0)?.replaceAll(' ', '');
    if (temperature == null || humidity == null) return null;

    final condition = lower.contains('tormenta')
        ? 'Tormenta'
        : lower.contains('lluvia')
        ? 'Lluvia'
        : lower.contains('nublado')
        ? 'Nublado'
        : 'Condiciones actuales';
    return NanoWeatherData(
      temperature: temperature,
      condition: condition,
      humidity: 'Humedad $humidity',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.055),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.location?.isNotEmpty == true) ...[
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: Color(0xFF64D2FF),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _AnimatedWeatherGlyph(),
              const SizedBox(width: 10),
              Text(
                data.temperature,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.condition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.humidity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (data.observedAt?.isNotEmpty == true ||
              data.consultedAt != null) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.09)),
            const SizedBox(height: 7),
            Text(
              _timeLine(data),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _timeLine(NanoWeatherData data) {
    final parts = <String>[];
    if (data.observedAt?.isNotEmpty == true) {
      parts.add('Observación ${data.observedAt}');
    }
    if (data.consultedAt case final value?) {
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      parts.add('consultado $hour:$minute');
    }
    return parts.join(' · ');
  }
}

class _AnimatedWeatherGlyph extends StatefulWidget {
  const _AnimatedWeatherGlyph();

  @override
  State<_AnimatedWeatherGlyph> createState() => _AnimatedWeatherGlyphState();
}

class _AnimatedWeatherGlyphState extends State<_AnimatedWeatherGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = reduceMotion ? 0.5 : _controller.value;
        return Transform.translate(
          offset: Offset(0, -1.5 * value),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFF0A84FF,
              ).withValues(alpha: 0.10 + (value * 0.08)),
            ),
            child: const Icon(
              Icons.cloud_rounded,
              size: 24,
              color: Color(0xFF64D2FF),
            ),
          ),
        );
      },
    );
  }
}
