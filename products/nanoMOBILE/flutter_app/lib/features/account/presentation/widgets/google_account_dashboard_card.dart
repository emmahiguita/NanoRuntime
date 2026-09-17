import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../google_account_provider.dart';
import 'google_account_dialog.dart';

/// Card Glassmórfica limpia oficial de Cuenta de Google para el Dashboard de Nano AI.
///
/// Muestra en tiempo real la identidad del usuario autenticado, estado de conexión viva
/// y accesos rápidos directos al Navegador Web Real y servicios cloud.
class GoogleAccountDashboardCard extends ConsumerWidget {
  const GoogleAccountDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(googleAccountProvider);
    final notifier = ref.read(googleAccountProvider.notifier);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1527).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Avatar con Borde Cuádruple Oficial de Google
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFF4285F4),
                          Color(0xFFEA4335),
                          Color(0xFFFBBC05),
                          Color(0xFF34A853),
                          Color(0xFF4285F4),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(2.2),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0F172A),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        profile.initials,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nombre y Correo
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
                                child: Text(
                                  profile.displayName,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: profile.isConnected
                                      ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.20)
                                      : const Color(0xFFEF4444)
                                          .withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: profile.isConnected
                                        ? const Color(0xFF10B981)
                                            .withValues(alpha: 0.5)
                                        : const Color(0xFFEF4444)
                                            .withValues(alpha: 0.5),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: profile.isConnected
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFFF87171),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile.isConnected ? 'Google' : 'Offline',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: profile.isConnected
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFFF87171),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.email,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botón Sincronizar en vivo
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await notifier.syncNow();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Icon(
                        Icons.sync_rounded,
                        size: 20,
                        color: notifier.isSyncing
                            ? const Color(0xFF38BDF8)
                            : Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Botón Ajustes de cuenta
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      GoogleAccountDialog.show(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Chip de Estado de Sincronización con Google
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _AccountActionChip(
                      icon: Icons.bolt_rounded,
                      label: profile.syncStatus,
                      isActive: profile.isConnected,
                      activeColor: const Color(0xFFFBBF24),
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await notifier.syncNow();
                      },
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

class _AccountActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _AccountActionChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        isActive ? activeColor : Colors.white.withValues(alpha: 0.45);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? effectiveColor.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? effectiveColor.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: effectiveColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
