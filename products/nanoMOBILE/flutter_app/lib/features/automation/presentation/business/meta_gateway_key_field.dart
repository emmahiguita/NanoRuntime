import 'package:flutter/material.dart';

/// Entrada privada reutilizable: sin sugerencias, autocorrección ni exposición del valor.
class MetaGatewayKeyField extends StatelessWidget {
  const MetaGatewayKeyField({
    super.key,
    required this.controller,
    required this.label,
    required this.enabled,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Vacío conserva el permiso guardado para este servidor.',
      ),
    ),
  );
}
