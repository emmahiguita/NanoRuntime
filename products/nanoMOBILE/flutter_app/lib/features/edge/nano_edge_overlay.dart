/// EDGE-01 — Widgets del búho DENTRO de la app (control y estado).
///
/// NO dibujan el overlay del sistema: la ventana nativa la pinta Android
/// (NanoOverlayView). Estos widgets son la superficie Flutter que el usuario
/// usa para encender/apagar el búho y ver qué contenido mostraría.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assistant_role.dart';
import 'nano_edge_controller.dart';

/// Badge de estado del overlay: disponible (accesibilidad conectada),
/// mostrando burbuja/panel, u oculto. Puro estado; sin side effects.
class NanoEdgeStatusBadge extends ConsumerWidget {
  const NanoEdgeStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(nanoEdgeControllerProvider);
    return FutureBuilder<bool>(
      future: controller.isAvailable(),
      builder: (context, snapshot) {
        final available = snapshot.data ?? false;
        final label = switch (available) {
          true => 'búho disponible',
          false => 'búho requiere accesibilidad',
        };
        return Tooltip(
          message: 'El overlay vive sobre cualquier app '
              '(TYPE_ACCESSIBILITY_OVERLAY). Sin el servicio de accesibilidad '
              'conectado no existe.',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: available
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

/// Conmutador del búho: muestra la burbuja sobre la app en foreground o la
/// oculta. Solo visible si el servicio de accesibilidad está conectado.
class NanoEdgeBubbleToggle extends ConsumerStatefulWidget {
  const NanoEdgeBubbleToggle({super.key});

  @override
  ConsumerState<NanoEdgeBubbleToggle> createState() =>
      _NanoEdgeBubbleToggleState();
}

class _NanoEdgeBubbleToggleState extends ConsumerState<NanoEdgeBubbleToggle> {
  bool _showing = false;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _refreshAvailability();
  }

  Future<void> _refreshAvailability() async {
    final available = await ref.read(nanoEdgeControllerProvider).isAvailable();
    if (!mounted) return;
    setState(() => _available = available);
  }

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: _showing,
      onChanged: _available
          ? (on) async {
              final controller = ref.read(nanoEdgeControllerProvider);
              final ok = on
                  ? await controller.showBubble()
                  : await controller.hideBubble();
              if (mounted) setState(() => _showing = ok ? on : _showing);
            }
          : null,
    );
  }
}

/// ROLE-01 — botón explícito "Hacer Nano mi asistente". La solicitud SOLO
/// ocurre cuando el usuario lo pulsa: nunca automática. Negar = estado
/// honesto (sigue "no seleccionado"), sin reintentos silenciosos.
class NanoAssistantRoleButton extends ConsumerStatefulWidget {
  const NanoAssistantRoleButton({super.key});

  @override
  ConsumerState<NanoAssistantRoleButton> createState() =>
      _NanoAssistantRoleButtonState();
}

class _NanoAssistantRoleButtonState
    extends ConsumerState<NanoAssistantRoleButton> {
  bool _holding = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshHolding();
  }

  Future<void> _refreshHolding() async {
    final holding = await ref.read(assistantRoleManagerProvider).isHoldingRole();
    if (!mounted) return;
    setState(() => _holding = holding);
  }

  Future<void> _requestRole() async {
    setState(() => _busy = true);
    try {
      final launched = await ref.read(assistantRoleManagerProvider).requestRole();
      // El usuario decide en el selector del sistema; al volver, el estado
      // se relee (nunca se asume concesión por haber lanzado el diálogo).
      await _refreshHolding();
      if (!mounted) return;
      if (!launched && !_holding) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El selector de asistente no está disponible en este dispositivo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy || _holding ? null : _requestRole,
      icon: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _holding ? Icons.assistant_rounded : Icons.person_add_alt_rounded,
              size: 18,
            ),
      label: Text(
        _holding ? 'Nano es tu asistente' : 'Hacer Nano mi asistente',
      ),
    );
  }
}
