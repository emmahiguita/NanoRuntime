import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../../../core/widgets/nano_owl_avatar.dart';

import '../../application/account_providers.dart';

/// QUÉ HACE:
/// Pantalla dedicada de agradecimiento y aporte voluntario a Nano.
///
/// CÓMO FUNCIONA:
/// Explica la filosofía del proyecto y permite realizar una contribución libre
/// mediante canales externos autorizados.
///
/// POR QUÉ:
/// Cumple la regla 13 y 34: separación jurídica y técnica estricta entre
/// suscripciones comerciales (Play Billing) y aportes voluntarios sin ventajas digitales.
class SupportNanoScreen extends ConsumerWidget {
  const SupportNanoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final notifier = ref.read(donationControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Apoyar a Nano', style: NanoType.headline(colors.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NanoSpacing.md),
          child: Column(
            children: [
              NanoOpticalSurface(
                borderRadius: NanoRadius.large,
                padding: const EdgeInsets.all(NanoSpacing.lg),
                child: Column(
                  children: [
                    const NanoOwlAvatar(size: 64, state: NanoOwlState.idle),
                    const SizedBox(height: NanoSpacing.md),
                    Text(
                      'Un proyecto impulsado por la comunidad',
                      style: NanoType.headline(colors.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nano Mobile es un sistema de IA y herramientas local-first diseñado para preservar tu privacidad e independencia tecnológica.',
                      style: NanoType.body(colors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NanoSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(NanoSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(NanoRadius.small),
                        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Los aportes voluntarios son 100% libres y no otorgan insignias, suscripciones Pro ni ventajas digitales.',
                              style: NanoType.caption(colors.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NanoSpacing.xl),
                    NanoActionButton(
                      label: 'Hacer aporte voluntario',
                      primary: true,
                      expanded: true,
                      icon: Icons.volunteer_activism_rounded,
                      onPressed: () => notifier.triggerSupportAction(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
