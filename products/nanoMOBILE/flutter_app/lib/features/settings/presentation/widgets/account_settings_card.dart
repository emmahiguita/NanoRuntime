import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../account/application/account_providers.dart';
import '../../../account/domain/account_profile.dart';
import '../../../account/domain/auth_user.dart';
import '../../../account/presentation/widgets/nano_support_banner.dart';
import '../../../automation/presentation/automation_visual_theme.dart';

part 'account_profile_card.part.dart';

/// Tarjeta ejecutiva de perfil de usuario para los Ajustes de Nano AI estilo Apple ID / iOS.
///
/// - QUÉ HACE: Presenta la tarjeta de usuario en Ajustes con estética limpia y sobria.
/// - CÓMO FUNCIONA: Desacopla la vista entre estados autenticado y no autenticado,
///   empleando [AutomationSurfaceCard] con borde neutro estructural sin refracciones coloridas.
/// - POR QUÉ: Sigue estrictamente la directiva de diseño ejecutivo iOS eliminando
///   bordes y acentos cromáticos no solicitados.
class AccountSettingsSection extends ConsumerWidget {
  const AccountSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final authState = ref.watch(sessionGateProvider);
    final donationState = ref.watch(donationControllerProvider);
    final donationNotifier = ref.read(donationControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (authState.isAuthenticated)
          _AuthenticatedProfileCard(
            colors: colors,
            user: authState.user,
            profile: authState.profile,
          )
        else
          _UnauthenticatedProfileCard(colors: colors),
        if (donationState.shouldShow)
          NanoSupportBanner(
            onSupportTap: () => donationNotifier.triggerSupportAction(),
            onDismissTap: () => donationNotifier.dismissBanner(),
          ),
      ],
    );
  }
}
