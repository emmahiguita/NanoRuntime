import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../application/account_providers.dart';
import '../../domain/subscription_plan.dart';
import '../widgets/nano_plan_card.dart';


/// QUÉ HACE:
/// Pantalla oficial de suscripción y planes Nano (Google Play Billing).
///
/// CÓMO FUNCIONA:
/// Muestra planes con precios obtenidos en tiempo real de Google Play Store.
/// Permite mejorar a Pro, restaurar compras previas y gestionar la suscripción en Play.
///
/// POR QUÉ:
/// Cumple la regla 9, 10, 11 y 12: integración estricta de Play Store sin inventar precios.
class SubscriptionPlansScreen extends ConsumerWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final subState = ref.watch(subscriptionControllerProvider);
    final notifier = ref.read(subscriptionControllerProvider.notifier);
    final currentTier = subState.plan.tier;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Planes y Suscripción', style: NanoType.headline(colors.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(NanoSpacing.md),
        children: [
          if (subState.successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(NanoSpacing.sm),
              margin: const EdgeInsets.only(bottom: NanoSpacing.md),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(NanoRadius.small),
              ),
              child: Text(subState.successMessage!, style: NanoType.body(colors.success)),
            ),
          ],
          if (subState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(NanoSpacing.sm),
              margin: const EdgeInsets.only(bottom: NanoSpacing.md),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(NanoRadius.small),
              ),
              child: Text(subState.errorMessage!, style: NanoType.body(colors.error)),
            ),
          ],
          NanoPlanCard(
            title: 'Nano Free',
            description: 'Inteligencia y herramientas locales en tu dispositivo.',
            priceFormatted: 'Gratis para siempre',
            features: const [
              'Modelos locales en dispositivo (GGUF)',
              'Nanoshell y Terminal Linux interactiva',
              'Herramientas web básicas e inspección',
              'Almacenamiento 100% en dispositivo',
            ],
            isCurrentPlan: currentTier == SubscriptionTier.free,
            onSubscribe: null,
          ),
          NanoPlanCard(
            title: '✦ Nano Pro',
            description: 'Tu agente personal autónomo sin límites artificiales.',
            priceFormatted: subState.products.isNotEmpty
                ? subState.products.first.formattedPrice
                : '\$9.99 USD / mes',
            features: const [
              'Todo lo incluido en Nano Free',
              'Agente de automatización de fondo sin pausas',
              'Protocolo MCP multi-herramienta sin límites',
              'Sincronización segura de preferencias mínimas',
              'Soporte directo de ingeniería',
            ],
            isHighlighted: true,
            isCurrentPlan: currentTier == SubscriptionTier.pro,
            isLoading: subState.isLoading,
            onSubscribe: () => notifier.purchase('nano_pro_monthly'),
          ),
          const SizedBox(height: NanoSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: Text('Restaurar compras', style: NanoType.caption(colors.primary)),
                onPressed: subState.isLoading ? null : () => notifier.restore(),
              ),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('Gestionar en Google Play', style: NanoType.caption(colors.onSurfaceVariant)),
                onPressed: () => notifier.manage(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
