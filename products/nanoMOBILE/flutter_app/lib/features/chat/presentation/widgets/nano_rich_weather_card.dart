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
      width: 105,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF10253D).withValues(alpha: 0.50),
        border: Border.all(
          color: const Color(0xFF58B4FF).withValues(alpha: 0.20),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nube y Lluvia con halo
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.cloud_rounded, size: 22, color: Color(0xFF93C5FD)),
                  Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.water_drop_rounded, size: 6.5, color: Color(0xFF38BDF8)),
                        SizedBox(width: 1.5),
                        Icon(Icons.water_drop_rounded, size: 6.5, color: Color(0xFF38BDF8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),

          // Temperatura principal
          Center(
            child: Text(
              temperature,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF0F6FC),
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Condición
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, size: 9, color: Color(0xFF38BDF8)),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  condition,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB0C4DE),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),

          // Humedad
          Row(
            children: [
              const Icon(Icons.opacity_rounded, size: 9, color: Color(0xFF38BDF8)),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  humidity,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 8.5,
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
