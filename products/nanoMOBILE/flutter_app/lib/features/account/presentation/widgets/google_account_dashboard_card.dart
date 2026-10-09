import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../google_account_provider.dart';
import 'google_account_dialog.dart';

/// Card Glassmórfica oficial iOS de Cuenta de Google / Servicios Cloud.
class GoogleAccountDashboardCard extends ConsumerWidget {
  const GoogleAccountDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(googleAccountProvider);
    final notifier = ref.read(googleAccountProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.50), width: 0.9),
            boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [
                        Color(0xFF4285F4), Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4),
                      ]),
                    ),
                    padding: const EdgeInsets.all(2.2),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.surface),
                      alignment: Alignment.center,
                      child: Text(profile.initials, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w800, color: colors.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        GoogleAccountDialog.show(context);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(profile.displayName, style: TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w700, color: colors.onSurface, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: profile.isConnected ? colors.success.withValues(alpha: 0.15) : colors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: profile.isConnected ? colors.success.withValues(alpha: 0.40) : colors.error.withValues(alpha: 0.40), width: 0.7),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: profile.isConnected ? colors.success : colors.error)),
                                    const SizedBox(width: 3.5),
                                    Text(profile.isConnected ? 'Cloud' : 'Offline', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: profile.isConnected ? colors.success : colors.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(profile.email, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: colors.onSurfaceVariant, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                  _HeaderIconButton(
                    icon: Icons.sync_rounded, colors: colors,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await notifier.syncNow();
                    },
                  ),
                  const SizedBox(width: 6),
                  _HeaderIconButton(
                    icon: Icons.tune_rounded, colors: colors,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      GoogleAccountDialog.show(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 9),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await notifier.syncNow();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: profile.isConnected ? colors.primary.withValues(alpha: 0.10) : colors.surfaceVariant.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: profile.isConnected ? colors.primary.withValues(alpha: 0.30) : colors.outlineVariant.withValues(alpha: 0.40), width: 0.7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(profile.isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, size: 13, color: profile.isConnected ? colors.primary : colors.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Text(profile.syncStatus, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: profile.isConnected ? colors.primary : colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final NanoColors colors;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.45), width: 0.7),
        ),
        child: Icon(icon, size: 18, color: colors.onSurfaceVariant),
      ),
    );
  }
}
