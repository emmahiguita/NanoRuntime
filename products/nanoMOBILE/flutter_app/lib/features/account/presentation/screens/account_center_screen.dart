import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../application/account_providers.dart';

import '../widgets/nano_account_tile.dart';
import '../widgets/nano_danger_dialog.dart';

/// QUÉ HACE:
/// Centro de gestión oficial de Cuenta Nano (Account Center).
///
/// CÓMO FUNCIONA:
/// Muestra avatar con iniciales, datos de perfil, plan activo, accesos a suscripciones,
/// dispositivos, apoyo voluntario, cierre de sesión y zona de peligro (eliminar cuenta).
///
/// POR QUÉ:
/// Cumple la regla 21 y 25: organiza toda la identidad de forma estructurada y segura.
class AccountCenterScreen extends ConsumerWidget {
  const AccountCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final authState = ref.watch(sessionGateProvider);
    final user = authState.user;
    final profile = authState.profile;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Cuenta Nano', style: NanoType.headline(colors.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(NanoSpacing.md),
        children: [
          _buildHeader(colors, user.displayName, user.email, profile.planTier, user.initials),
          const SizedBox(height: NanoSpacing.lg),
          Text('SERVICIOS Y DISPOSITIVOS', style: NanoType.overline(colors.onSurfaceVariant)),
          const SizedBox(height: NanoSpacing.xs),
          NanoAccountTile(
            icon: Icons.star_outline_rounded,
            title: 'Plan y suscripción',
            subtitle: 'Gestionar o mejorar tu plan actual (${profile.planTier.toUpperCase()})',
            onTap: () => context.push('/account/subscription'),
          ),
          NanoAccountTile(
            icon: Icons.devices_rounded,
            title: 'Dispositivos vinculados',
            subtitle: 'Administrar sesiones en Mobile, Desktop y Web',
            onTap: () => context.push('/account/devices'),
          ),
          NanoAccountTile(
            icon: Icons.volunteer_activism_outlined,
            title: 'Apoyar Nano',
            subtitle: 'Aporte voluntario para el desarrollo del proyecto',
            onTap: () => context.push('/account/support'),
          ),
          const SizedBox(height: NanoSpacing.lg),
          Text('SESIÓN', style: NanoType.overline(colors.onSurfaceVariant)),
          const SizedBox(height: NanoSpacing.xs),
          NanoAccountTile(
            icon: Icons.logout_rounded,
            title: 'Cerrar sesión',
            subtitle: 'Revoca la sesión activa sin borrar datos locales',
            onTap: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/auth/login');
            },
          ),
          const SizedBox(height: NanoSpacing.lg),
          Text('ZONA DE PELIGRO', style: NanoType.overline(colors.error)),
          const SizedBox(height: NanoSpacing.xs),
          NanoAccountTile(
            icon: Icons.delete_forever_rounded,
            title: 'Eliminar cuenta',
            subtitle: 'Borra definitivamente tu cuenta y datos asociados',
            isDanger: true,
            onTap: () async {
              final confirmed = await NanoDangerDialog.show(
                context: context,
                title: '¿Eliminar tu cuenta?',
                message: 'Esta acción es irreversible. Se eliminará tu perfil, suscripciones y configuración en la nube. Tus datos locales se desvincularán.',
                confirmLabel: 'Sí, eliminar cuenta',
              );
              if (confirmed == true && context.mounted) {
                await ref.read(authControllerProvider.notifier).deleteAccount();
                if (context.mounted) context.go('/auth/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    NanoColors colors,
    String name,
    String email,
    String plan,
    String initials,
  ) {
    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      padding: const EdgeInsets.all(NanoSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            child: Text(initials, style: NanoType.headline(colors.primary)),
          ),
          const SizedBox(width: NanoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Usuario Nano',
                  style: NanoType.title(colors.onSurface),
                ),
                Text(email, style: NanoType.caption(colors.onSurfaceVariant)),
                const SizedBox(height: 4),
                NanoBadge(
                  plan.toUpperCase(),
                  kind: plan.toLowerCase() == 'free'
                      ? BadgeKind.neutral
                      : BadgeKind.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
