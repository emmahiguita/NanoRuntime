// QUÉ HACE: Distingue una prueba local de la falta de mediciones para el teléfono.
// CÓMO FUNCIONA: Consulta el registro local por el nombre exacto del modelo.
// POR QUÉ: Un resultado de otro modelo o teléfono no predice el rendimiento del OPPO.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/nano_optical_surface.dart';
import '../../domain/mobile_hardware_benchmark.dart';

class ModelDeviceEvidenceCard extends StatelessWidget {
  final String modelName;

  const ModelDeviceEvidenceCard({super.key, required this.modelName});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final benchmark = MobileHardwareBenchmarkRegistry.findForModel(modelName);
    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            benchmark == null
                ? Icons.info_outline_rounded
                : Icons.speed_rounded,
            size: 17,
            color: benchmark == null
                ? const Color(0xFF38BDF8)
                : const Color(0xFF34D399),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benchmark == null
                      ? 'Sin medición en OPPO CPH2557'
                      : 'Prueba local previa · ${benchmark.phoneTested}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                if (benchmark != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${benchmark.soc} · ≈${benchmark.tokensPerSec.toStringAsFixed(2)} tok/s · TTFT ≈${benchmark.ttftSeconds.toStringAsFixed(1)} s',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  benchmark?.sampleNote ??
                      'La velocidad de este modelo aún no se ha medido en este equipo.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
