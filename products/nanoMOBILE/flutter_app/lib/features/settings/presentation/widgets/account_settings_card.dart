import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../../account/application/account_providers.dart';

import '../../../account/presentation/widgets/nano_support_banner.dart';

/// QUÉ HACE:
/// Tarjeta de resumen de Cuenta Nano y banner de apoyo para la pantalla de Ajustes.
///
/// CÓMO FUNCIONA:
/// Observa [sessionGateProvider] y [donationControllerProvider].
/// Si hay sesión, muestra el nombre, correo y badge de plan con acceso a `/account`.
/// Si el banner de apoyo voluntario debe mostrarse, lo renderiza elegantemente.
///
/// POR QUÉ:
/// Conecta el módulo de cuenta con la experiencia general de Nano sin duplicar lógica.
class AccountSettingsSection extends ConsumerWidget {
  const AccountSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final authState = ref.watch(sessionGateProvider);
    final donationState = ref.watch(donationControllerProvider);
    final donationNotifier = ref.read(donationControllerProvider.notifier);

    final user = authState.user;
    final profile = authState.profile;
    final isAuth = authState.isAuthenticated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NanoOpticalSurface(
          borderRadius: NanoRadius.large,
          padding: const EdgeInsets.all(NanoSpacing.md),
          margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
          onTap: () {
            if (isAuth) {
              context.push('/account');
            } else {
              context.push('/auth/login');
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.primary.withValues(alpha: 0.15),
                child: Text(
                  isAuth ? user.initials : '?',
                  style: NanoType.title(colors.primary),
                ),
              ),
              const SizedBox(width: NanoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAuth
                          ? (user.displayName.isNotEmpty
                              ? user.displayName
                              : 'Usuario Nano')
                          : 'Iniciar sesión en Nano',
                      style: NanoType.title(colors.onSurface),
                    ),
                    Text(
                      isAuth ? user.email : 'Sincroniza y gestiona tu plan',
                      style: NanoType.caption(colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isAuth)
                NanoBadge(
                  profile.planTier.toUpperCase(),
                  kind: profile.isPro ? BadgeKind.success : BadgeKind.neutral,
                )
              else
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: colors.onSurfaceVariant),
            ],
          ),
        ),
        if (donationState.shouldShow)
          NanoSupportBanner(
            onSupportTap: () => donationNotifier.triggerSupportAction(),
            onDismissTap: () => donationNotifier.dismissBanner(),
          ),
      ],
    );
  }
}
