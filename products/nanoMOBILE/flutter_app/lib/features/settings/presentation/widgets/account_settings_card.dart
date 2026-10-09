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

/// Tarjeta ejecutiva de perfil de usuario para los Ajustes de Nano AI.
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
      borderRadius: NanoRadius.medium,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 6),
      onTap: () => context.push('/account'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [colors.primary.withValues(alpha: 0.35), colors.primary.withValues(alpha: 0.12)],
                      ),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.45), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: _renderAvatar(photoUrl, initials),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: NanoType.headline(colors.onSurface).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(Icons.verified_rounded, size: 16, color: colors.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              NanoBadge(
                profile.planTier.toUpperCase(),
                kind: profile.isPro ? BadgeKind.success : BadgeKind.neutral,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chip(Icons.shield_outlined, 'Local-first'),
              _chip(Icons.lock_outline_rounded, 'E2E Cifrado'),
              _chip(
                profile.syncEnabled ? Icons.cloud_done_outlined : Icons.devices_rounded,
                profile.syncEnabled ? 'Sincronizado' : 'Dispositivo Local',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.35), height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gestionar cuenta y privacidad',
                style: NanoType.caption(colors.primary).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: colors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _renderAvatar(String? path, String initials) {
    if (path == null || path.isEmpty) return _initials(initials);
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') {
      return ClipOval(child: Image.network(path, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials(initials)));
    }
    final file = File(path);
    if (file.existsSync()) {
      return ClipOval(child: Image.file(file, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials(initials)));
    }
    return _initials(initials);
  }

  Widget _initials(String text) => Text(
    text,
    style: NanoType.headline(colors.primary).copyWith(fontWeight: FontWeight.w800, fontSize: 16),
  );

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colors.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class _UnauthenticatedProfileCard extends StatelessWidget {
  final NanoColors colors;
  const _UnauthenticatedProfileCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 6),
      onTap: () => context.push('/account'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.primary.withValues(alpha: 0.30), width: 1.2),
                ),
                child: Icon(Icons.person_outline_rounded, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfil Soberano Nano',
                      style: NanoType.headline(colors.onSurface).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Identidad local, privacidad y modelos fuera de línea.',
                      style: NanoType.caption(colors.onSurfaceVariant).copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                child: Text(
                  '¿Tienes cuenta? Inicia sesión aquí',
                  style: NanoType.caption(colors.primary).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/account'),
                child: Row(
                  children: [
                    Text(
                      'Abrir Perfil',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
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