import 'package:flutter/material.dart';

/// Tarjeta contextual enriquecida estilo 3D Glass (ej. reporte de clima / datos).
class NanoRichWeatherCard extends StatelessWidget {
  final String location;
  final String temperature;
  final String condition;
  final String humidity;

  const NanoRichWeatherCard({
    super.key,
    this.location = 'Alpujarra, Colombia',
    this.temperature = '15°C',
    this.condition = 'Lluvia moderada',
    this.humidity = 'Humedad 99%',
  });

  /// Detector inteligente si el texto contiene datos meteorológicos
  static bool hasWeatherData(String text) {
    final lower = text.toLowerCase();
    return (lower.contains('clima') || lower.contains('temperatura') || lower.contains('celsius') || lower.contains('grados') || lower.contains('lluvia') || lower.contains('humedad')) &&
           (lower.contains('°') || lower.contains('celsius') || lower.contains('humedad'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 125,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF132A42),
            Color(0xFF091422),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF58B4FF).withValues(alpha: 0.25),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nube y Lluvia 3D con halo
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.cloud_rounded, size: 28, color: Color(0xFF93C5FD)),
                  Positioned(
                    bottom: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.water_drop_rounded, size: 8, color: Color(0xFF38BDF8)),
                        SizedBox(width: 2),
                        Icon(Icons.water_drop_rounded, size: 8, color: Color(0xFF38BDF8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Temperatura principal
          Center(
            child: Text(
              temperature,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF0F6FC),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Condición
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, size: 10, color: Color(0xFF38BDF8)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  condition,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB0C4DE),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Humedad
          Row(
            children: [
              const Icon(Icons.opacity_rounded, size: 10, color: Color(0xFF38BDF8)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  humidity,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8FA8C4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
