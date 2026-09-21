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
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x22FFFFFF), width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _segment(
                    title: 'Todos los contactos',
                    icon: Icons.public_rounded,
                    selected: isAll,
                    color: const Color(0xFF00E676),
                    onTap: () => ref.read(settingsProvider.notifier).setWaTargetContactsMode('all'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _segment(
                    title: 'Solo seleccionados',
                    icon: Icons.playlist_add_check_rounded,
                    selected: !isAll,
                    color: const Color(0xFF00D2FF),
                    onTap: () => ref.read(settingsProvider.notifier).setWaTargetContactsMode('selected'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAll ? const Color(0x0E00E676) : const Color(0x0E00D2FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAll ? const Color(0x3300E676) : const Color(0x3300D2FF),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isAll ? Icons.info_outline_rounded : Icons.shield_outlined,
                  size: 14,
                  color: isAll ? const Color(0xFF00E676) : const Color(0xFF00D2FF),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAll ? 'AGENTE ACTIVO: TODOS LOS CONTACTOS' : 'AGENTE ACTIVO: SOLO CONTACTOS SELECCIONADOS',
                        style: TextStyle(
                          color: isAll ? const Color(0xFF00E676) : const Color(0xFF00D2FF),
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
                        style: const TextStyle(fontSize: 10, height: 1.25, color: Colors.white70),
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
    required String title,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: selected ? color : Colors.white60),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? color : Colors.white70,
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
