/// ROLE-01 — botón explícito "Hacer Nano mi asistente".
///
/// La solicitud SOLO ocurre cuando el usuario lo pulsa: nunca automática.
/// Abre el selector del sistema y jamás fuerza la concesión. Negar = estado
/// honesto (sigue "no seleccionado"), sin reintentos silenciosos.
///
/// Antes vivía en nano_edge_overlay.dart (junto a los widgets del búho);
/// con el búho retirado (el icono de accesibilidad del sistema ya da
/// acceso), el botón queda como único control del role en la sección Dev.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assistant_role.dart';

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
      final launched = await ref
          .read(assistantRoleManagerProvider)
          .requestRole();
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
