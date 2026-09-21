import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';


/// QUÉ HACE:
/// Tarjeta visual para planes de suscripción (Free, Pro, Business).
///
/// CÓMO FUNCIONA:
/// Muestra los detalles del plan, precio oficial desde Play Billing, lista de features
/// y botón de acción principal o indicador de plan actual.
///
/// POR QUÉ:
/// Garantiza que los precios no estén hardcodeados y resalta el diseño glass premium.
class NanoPlanCard extends StatelessWidget {
  final String title;
  final String description;
  final String priceFormatted;
  final List<String> features;
  final bool isCurrentPlan;
  final bool isHighlighted;
  final VoidCallback? onSubscribe;
  final bool isLoading;

  const NanoPlanCard({
    super.key,
    required this.title,
    required this.description,
    required this.priceFormatted,
    required this.features,
    this.isCurrentPlan = false,
    this.isHighlighted = false,
    this.onSubscribe,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      isActive: isHighlighted,
      padding: const EdgeInsets.all(NanoSpacing.md),
      margin: const EdgeInsets.only(bottom: NanoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: NanoType.headline(colors.onSurface)),
              if (isCurrentPlan)
                const NanoBadge('Tu plan actual', kind: BadgeKind.accent)
              else if (isHighlighted)
                const NanoBadge('✦ Recomendado', kind: BadgeKind.success),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: NanoType.caption(colors.onSurfaceVariant)),
          const SizedBox(height: NanoSpacing.sm),
          Text(
            priceFormatted,
            style: NanoType.title(isHighlighted ? colors.primary : colors.onSurface),
          ),
          const SizedBox(height: NanoSpacing.md),
          ...features.map((feat) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(feat, style: NanoType.body(colors.onSurface)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: NanoSpacing.md),
          if (!isCurrentPlan)
            NanoActionButton(
              label: isHighlighted ? 'Mejorar a Pro' : 'Seleccionar',
              primary: isHighlighted,
              expanded: true,
              onPressed: isLoading ? null : onSubscribe,
            ),
        ],
      ),
    );
  }
}
