// model_detail_use_cases.dart — Casos de uso recomendados en la ficha técnica de modelos.
// QUÉ HACE: Despliega cápsulas visuales con iconos temáticos (Chat, Imágenes, Resúmenes, Asistente).
// CÓMO FUNCIONA: Cuadrícula de 2 columnas con colores semánticos Material Expressive 3.
// POR QUYÉ: Facilita al usuario entender el propósito práctico del modelo (< 100 líneas).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class ModelDetailUseCases extends StatelessWidget {
  final bool isMultimodal;
  final bool isVoice;

  const ModelDetailUseCases({
    super.key,
    required this.isMultimodal,
    required this.isVoice,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    final cases = isVoice
        ? [
            const _UseCaseItem(label: 'Transcripción continua', icon: Icons.mic_rounded, color: Color(0xFF10B981)),
            const _UseCaseItem(label: 'Dictado de notas y chat', icon: Icons.notes_rounded, color: Color(0xFF38BDF8)),
            const _UseCaseItem(label: 'Comandos de voz sin red', icon: Icons.offline_bolt_rounded, color: Color(0xFFFBBF24)),
            const _UseCaseItem(label: 'Privacidad absoluta', icon: Icons.security_rounded, color: Color(0xFFA78BFA)),
          ]
        : [
            const _UseCaseItem(label: 'Chat conversacional', icon: Icons.chat_bubble_outline_rounded, color: Color(0xFF10B981)),
            _UseCaseItem(
              label: isMultimodal ? 'Análisis de imágenes' : 'Extracción estructurada',
              icon: isMultimodal ? Icons.image_search_rounded : Icons.data_object_rounded,
              color: const Color(0xFF38BDF8),
            ),
            const _UseCaseItem(label: 'Resúmenes y síntesis', icon: Icons.description_outlined, color: Color(0xFFFBBF24)),
            const _UseCaseItem(label: 'Asistente personal offline', icon: Icons.person_outline_rounded, color: Color(0xFFA78BFA)),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Casos de uso',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            Text(
              'Recomendados',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.8,
          ),
          itemCount: cases.length,
          itemBuilder: (context, index) {
            final c = cases[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(NanoRadius.medium),
                border: Border.all(color: c.color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(c.icon, size: 16, color: c.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _UseCaseItem {
  final String label;
  final IconData icon;
  final Color color;
  const _UseCaseItem({required this.label, required this.icon, required this.color});
}
