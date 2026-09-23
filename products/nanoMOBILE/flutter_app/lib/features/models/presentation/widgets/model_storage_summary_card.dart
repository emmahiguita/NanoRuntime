// model_storage_summary_card.dart — Resumen de almacenamiento y orquestación de escaneo / SD.
// QUÉ HACE: Muestra espacio ocupado por modelos y acciones para escanear storage o importar .gguf desde SD.
// CÓMO FUNCIONA: Tarjeta NanoOpticalSurface con control de desbordamiento elástico y botón táctil de carga.
// POR QUÉ: Otorga control de ubicación de pesos sin fugas visuales ni RenderFlex overflow (<200 líneas).
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/nano_optical_surface.dart';
import 'model_action_components.dart';

class ModelStorageSummaryCard extends StatelessWidget {
  final double totalInstalledGb;
  final int totalInstalledCount;
  final bool isScanning;
  final String? downloadDir;
  final VoidCallback onScan;
  final VoidCallback onPickDownloadDir;
  final VoidCallback onImportFromSd;

  const ModelStorageSummaryCard({
    super.key,
    required this.totalInstalledGb,
    required this.totalInstalledCount,
    required this.isScanning,
    required this.downloadDir,
    required this.onScan,
    required this.onPickDownloadDir,
    required this.onImportFromSd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almacenamiento de Modelos',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalInstalledCount en memoria • ${totalInstalledGb.toStringAsFixed(1)} GB en uso',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: colors.onSurfaceVariant),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isScanning)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IosActionButton(
                  label: 'Escanear',
                  icon: Icons.radar_rounded,
                  onTap: onScan,
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Botón destacado: Abrir modelo desde SD / Almacenamiento libre
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(NanoRadius.medium),
              border: Border.all(color: colors.primary.withValues(alpha: 0.20), width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.sd_card_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cargar desde Tarjeta SD o Almacenamiento',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        downloadDir != null ? 'Ruta: $downloadDir' : 'Ejecuta cualquier .gguf directo sin duplicar espacio',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: colors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IosActionButton(
                  label: 'Elegir SD',
                  icon: Icons.folder_open_rounded,
                  color: colors.primary,
                  filled: true,
                  onTap: onImportFromSd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
