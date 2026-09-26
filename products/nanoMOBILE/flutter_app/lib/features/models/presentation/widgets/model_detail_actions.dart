// model_detail_actions.dart — Botones de acción y especificaciones para el detalle del modelo.
// QUÉ HACE: Construye los botones de Cargar/Descargar/Desconectar/Eliminar y chips de especificaciones.
// CÓMO FUNCIONA: Acciones tipadas según el estado del modelo (activo, instalado, disponible).
// POR QUÉ: Desacopla la botonera del modal principal para cumplir con la regla de < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class ModelDetailActions extends StatelessWidget {
  final bool isActive;
  final bool isInstalled;
  final bool isVoice;
  final bool isCatalog;
  final VoidCallback? onUse;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onUnload;
  final VoidCallback? onDelete;

  const ModelDetailActions({
    super.key,
    required this.isActive,
    required this.isInstalled,
    required this.isVoice,
    this.isCatalog = true,
    this.onUse,
    this.onDownload,
    this.onCancel,
    this.onUnload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    if (isActive) {
      final msg = isVoice ? 'Voz Local Activa (Whisper)' : 'Modelo Activo';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(NanoRadius.medium),
              border: Border.all(color: const Color(0xFF10B981), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  msg,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NanoRadius.medium),
              ),
            ),
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: Text(
              isVoice ? 'Desactivar voz local' : 'Desconectar modelo',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onUnload?.call();
            },
          ),
        ],
      );
    }

    if (isInstalled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NanoRadius.medium),
              ),
            ),
            icon: Icon(
              isVoice ? Icons.mic_rounded : Icons.play_arrow_rounded,
              size: 18,
            ),
            label: Text(
              isVoice ? 'Activar para Voz Local' : 'Cargar en Chat',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onUse?.call();
            },
          ),
          if (onDelete != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NanoRadius.medium),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                isCatalog
                    ? 'Eliminar archivo descargado'
                    : 'Eliminar de almacenamiento',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ],
      );
    }

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NanoRadius.medium),
        ),
      ),
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text(
        'Descargar modelo',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
      ),
      onPressed: () {
        Navigator.pop(context);
        onDownload?.call();
      },
    );
  }
}

