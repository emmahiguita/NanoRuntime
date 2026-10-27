// QUÉ: destino real del dock con icono Nano y nombre visible.
// CÓMO: una sola superficie de selección, sin otro desenfoque por botón.
// POR QUÉ: evita lentes superpuestas, saltos de tamaño y acciones ambiguas.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_destination.dart';
import 'nano_destination_icon.dart';

class NanoNavDestinationItem extends StatelessWidget {
  const NanoNavDestinationItem({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.brightness,
    required this.onSelect,
    this.compact = false,
  });
  final NanoDestination destination;
  final bool isSelected;
  final Brightness brightness;
  final ValueChanged<NanoDestination> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final color = isSelected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (isSelected) return;
            HapticFeedback.selectionClick();
            onSelect(destination);
          },
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(
              minWidth: 48,
              minHeight: compact ? 48 : 60,
            ),
            padding: EdgeInsets.symmetric(
              vertical: compact ? 3 : 5,
              horizontal: 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: isSelected
                  ? scheme.primary.withValues(alpha: .10)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? scheme.primary.withValues(alpha: .20)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NanoDestinationIcon(
                  destination: destination,
                  size: compact ? 23 : 27,
                  color: color,
                ),
                SizedBox(height: compact ? 2 : 3),
                Text(
                  destination == NanoDestination.automation
                      ? 'Inicio'
                      : destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
