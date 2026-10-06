import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/design_tokens.dart';

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
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final mode = settings.waTargetContactsMode;
    final isAll = mode == 'all';

    final allColor = isDark ? const Color(0xFF00E676) : const Color(0xFF059669);
    final selectedColor = isDark ? const Color(0xFF00D2FF) : const Color(0xFF0284C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x14FFFFFF) : colors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0x22FFFFFF) : colors.outline.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _segment(
                    context: context,
                    title: 'Todos los contactos',
                    icon: Icons.public_rounded,
                    selected: isAll,
                    color: allColor,
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
                    color: selectedColor,
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAll
                  ? allColor.withValues(alpha: isDark ? 0.08 : 0.10)
                  : selectedColor.withValues(alpha: isDark ? 0.08 : 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAll
                    ? allColor.withValues(alpha: 0.35)
                    : selectedColor.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isAll ? Icons.info_outline_rounded : Icons.shield_outlined,
                  size: 14,
                  color: isAll ? allColor : selectedColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAll
                            ? 'AGENTE ACTIVO: TODOS LOS CONTACTOS'
                            : 'AGENTE ACTIVO: SOLO CONTACTOS SELECCIONADOS',
                        style: TextStyle(
                          color: isAll ? allColor : selectedColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        isAll
                            ? 'Nano responderá a cualquier contacto entrante. Puedes pausar contactos específicos con su switch.'
                            : 'Nano responderá ÚNICAMENTE a contactos con el switch de agente encendido.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.25,
                          color: colors.onSurfaceVariant,
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
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? color.withValues(alpha: 0.2) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? (isDark ? color.withValues(alpha: 0.5) : colors.outline.withValues(alpha: 0.4))
                : Colors.transparent,
            width: 0.8,
          ),
          boxShadow: selected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? color : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? color : colors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
