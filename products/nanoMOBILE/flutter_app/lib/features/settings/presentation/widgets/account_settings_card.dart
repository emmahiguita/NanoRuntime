import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import '../../../../core/widgets/nano_components.dart';
import '../../../account/application/account_providers.dart';
import '../../../account/domain/account_profile.dart';
import '../../../account/domain/auth_user.dart';
import '../../../account/presentation/widgets/nano_support_banner.dart';

/// QUÉ HACE: Tarjeta ejecutiva de perfil de usuario para los Ajustes de Nano AI.
/// CÓMO FUNCIONA: Observa reactivamente [sessionGateProvider]. Adapta a horizontal y vertical.
/// POR QUÉ: Reemplaza la card básica por un componente corporativo profesional y didáctico.
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
          _AuthenticatedProfileCard(colors: colors, user: authState.user, profile: authState.profile)
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

/// QUÉ HACE: Vista completa del perfil autenticado con avatar vivo, identidad y chips.
/// CÓMO FUNCIONA: Soporta rutas de avatar locales y remotas, y navega a `/account` con feedback haptic.
/// POR QUÉ: Tipado fuerte contra AuthUser y AccountProfile previniendo NoSuchMethodError y crashes de red.
class _AuthenticatedProfileCard extends StatelessWidget {
  final NanoColors colors;
  final AuthUser user;
  final AccountProfile profile;

  const _AuthenticatedProfileCard({required this.colors, required this.user, required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName.isNotEmpty ? profile.displayName : (user.displayName.isNotEmpty ? user.displayName : 'Usuario Soberano');
    final email = profile.email.isNotEmpty ? profile.email : (user.email.isNotEmpty ? user.email : 'usuario@nano.ai');
    final initials = profile.displayName.trim().isEmpty ? user.initials : profile.displayName.trim().characters.first.toUpperCase();
    final photoUrl = profile.photoUrl ?? user.photoUrl;

    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      padding: const EdgeInsets.all(NanoSpacing.md),
      margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
      onTap: () => context.push('/account'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar con halo verde e indicador de actividad viva
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [colors.primary.withValues(alpha: 0.3), colors.primary.withValues(alpha: 0.1)]),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: _renderAvatar(photoUrl, initials),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: colors.success, shape: BoxShape.circle, border: Border.all(color: colors.surface, width: 2)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: NanoSpacing.md),
              // Identidad (evita salto de línea indebido)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(name, style: NanoType.headline(colors.onSurface).copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        Icon(Icons.verified_rounded, size: 16, color: colors.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(email, style: NanoType.caption(colors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: NanoSpacing.xs),
              NanoBadge(profile.planTier.toUpperCase(), kind: profile.isPro ? BadgeKind.success : BadgeKind.neutral),
            ],
          ),
          const SizedBox(height: 10),
          // Chips informativos Material Expressive
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chip(Icons.shield_outlined, 'Local-first'),
              _chip(Icons.lock_outline_rounded, 'E2E Cifrado'),
              _chip(profile.syncEnabled ? Icons.cloud_done_outlined : Icons.devices_rounded, profile.syncEnabled ? 'Sincronizado' : 'Dispositivo Local'),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.35), height: 1),
          const SizedBox(height: 8),
          // Pie de acción para navegar al centro de cuenta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gestionar cuenta y privacidad', style: NanoType.caption(colors.primary).copyWith(fontWeight: FontWeight.w600)),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: colors.primary),
            ],
          ),
        ],
      ),
    );
  }

  /// CÓMO FUNCIONA: Discrimina entre URI web (http/https), archivo local en almacenamiento y fallback de iniciales.
  Widget _renderAvatar(String? path, String initials) {
    if (path == null || path.isEmpty) return _initials(initials);
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') {
      return ClipOval(child: Image.network(path, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials(initials)));
    }
    final file = File(path);
    if (file.existsSync()) {
      return ClipOval(child: Image.file(file, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials(initials)));
    }
    return _initials(initials);
  }

  Widget _initials(String text) => Text(text, style: NanoType.headline(colors.primary).copyWith(fontWeight: FontWeight.w800));

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.primary.withValues(alpha: 0.20))),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colors.primary),
        const SizedBox(width: 4),
        Text(label, style: NanoType.overline(colors.onSurfaceVariant).copyWith(fontWeight: FontWeight.w600, fontSize: 10)),
      ],
    ),
  );
}

/// QUÉ HACE: Tarjeta accesible para invitar al usuario a iniciar sesión o entrar directamente a su perfil local.
/// CÓMO FUNCIONA: Ofrece acción principal clara con botones de Iniciar Sesión y Ver Centro de Perfil.
/// POR QUÉ: Permite navegar sin trabas a los usuarios que usan la app en modo local soberano.
class _UnauthenticatedProfileCard extends StatelessWidget {
  final NanoColors colors;
  const _UnauthenticatedProfileCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      padding: const EdgeInsets.all(NanoSpacing.md),
      margin: const EdgeInsets.only(bottom: NanoSpacing.sm),
      onTap: () => context.push('/account'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.person_outline_rounded, color: colors.primary, size: 24),
              ),
              const SizedBox(width: NanoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Perfil Soberano Nano', style: NanoType.headline(colors.onSurface).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Configura tu identidad local y modelos fuera de línea.', style: NanoType.caption(colors.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.35), height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => context.push('/auth/login'),
                child: Text('¿Tienes cuenta? Inicia sesión aquí', style: NanoType.caption(colors.primary).copyWith(fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                onTap: () => context.push('/account'),
                child: Row(
                  children: [
                    Text('Abrir Perfil', style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}