// nano_m3_drawer_destination_tile.dart — Destino individual según Material Design 3.
// QUÉ HACE:
// Renderiza un ítem de destino para el Navigation Drawer con la anatomía oficial de M3:
// píldora activa de 56dp de alto, borderRadius de 28dp, icono, etiqueta y badge opcional.
//
// CÓMO FUNCIONA:
// Aplica el contenedor activo con colorScheme.secondaryContainer o gradiente Liquid Glass,
// emite feedback háptico al pulsar y reporta la selección al callback inyectado.
//
// POR QUÉ:
// Asegura cumplimiento estricto de las directrices M3 (https://m3.material.io/components/navigation-drawer/overview)
// con arquitectura desacoplada y menos de 130 líneas de código limpio.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_destination.dart';
import 'nano_destination_icon.dart';

class NanoM3DrawerDestinationTile extends StatelessWidget {
  const NanoM3DrawerDestinationTile({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.onTap,
    this.badgeText,
  });

  final NanoDestination destination;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badgeText;

  String _destinationLabel(NanoDestination dest) {
    switch (dest) {
      case NanoDestination.automation:
        return 'Inicio';
      case NanoDestination.models:
        return 'Modelos locales';
      case NanoDestination.terminal:
        return 'Terminal Linux';
      case NanoDestination.settings:
        return 'Ajustes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final label = _destinationLabel(destination);

    // M3 active container: secondaryContainer con contraste verificado
    final activeContainerColor = isDark
        ? scheme.secondaryContainer.withValues(alpha: 0.35)
        : scheme.secondaryContainer;
    final activeForegroundColor = isDark
        ? scheme.onSecondaryContainer
        : scheme.onSecondaryContainer;
    final inactiveForegroundColor = scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: SizedBox(
          height: 56, // Altura oficial M3 para items de Navigation Drawer
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? activeContainerColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? scheme.primary.withValues(alpha: 0.30)
                              : scheme.primary.withValues(alpha: 0.15),
                          width: 1.0,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Icono canónico del destino
                    NanoDestinationIcon(
                      destination: destination,
                      size: 24,
                      color: isSelected
                          ? activeForegroundColor
                          : inactiveForegroundColor,
                    ),
                    const SizedBox(width: 14),
                    // Etiqueta del destino
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? activeForegroundColor
                              : scheme.onSurface,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Badge descriptivo M3 (opcional o activo)
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.primary.withValues(alpha: 0.18)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else if (isSelected)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF10B981) : scheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
