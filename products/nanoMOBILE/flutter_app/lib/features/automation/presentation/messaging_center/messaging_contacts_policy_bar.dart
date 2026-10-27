import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';

/// MESSAGING-CONTACTS-POLICY-BAR — Selector Glassmorphism de política del agente.
///
/// **QUÉ HACE:**
/// Permite al usuario elegir si el agente responde en todos los contactos de WhatsApp
/// o únicamente en los contactos seleccionados manualmente.
///
/// **CÓMO FUNCIONA:**
/// Alterna entre los modos 'all' y 'selected' en [settingsProvider] y muestra
/// una tarjeta glassmorphism translúcida explicativa en tiempo real.
///
/// **POR QUÉ:**
/// Otorga al usuario control granular y predecible con diseño glasses y tipografía compacta.
class MessagingContactsPolicyBar extends ConsumerWidget {
  const MessagingContactsPolicyBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final mode = settings.waTargetContactsMode;
    final isAll = mode == 'all';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.85),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _segment(
                    context: context,
                    title: 'Todos los contactos',
                    icon: Icons.public_rounded,
                    selected: isAll,
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setWaTargetContactsMode('all'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _segment(
                    context: context,
                    title: 'Solo seleccionados',
                    icon: Icons.playlist_add_check_rounded,
                    selected: !isAll,
                    onTap: () => ref
                        .read(settingsProvider.notifier)
                        .setWaTargetContactsMode('selected'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isAll ? Icons.info_outline_rounded : Icons.shield_outlined,
                  size: 14,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAll
                            ? 'AGENTE ACTIVO: TODOS LOS CONTACTOS'
                            : 'AGENTE ACTIVO: SOLO CONTACTOS SELECCIONADOS',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        isAll
                            ? 'Nano responderá a cualquier contacto entrante. Puedes pausar contactos específicos con su switch.'
                            : 'Nano responderá ÚNICAMENTE a contactos con el switch de agente encendido.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.25,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderGradient = selected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                    const Color(0xFF38BDF8).withValues(alpha: 0.55),
                    const Color(0xFF818CF8).withValues(alpha: 0.40),
                    const Color(0xFFFFFFFF).withValues(alpha: 0.20),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFF38BDF8).withValues(alpha: 0.70),
                    const Color(0xFF94A3B8),
                  ],
          )
        : null;

    final bgGradient = selected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF334155).withValues(alpha: 0.80),
                    const Color(0xFF1E293B).withValues(alpha: 0.90),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.95),
                    const Color(0xFFF1F5F9).withValues(alpha: 0.90),
                  ],
          )
        : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: borderGradient,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.20 : 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 1.5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.all(selected ? 1.2 : 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: bgGradient,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected
                    ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
