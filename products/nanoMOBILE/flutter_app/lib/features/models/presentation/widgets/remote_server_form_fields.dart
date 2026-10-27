// remote_server_form_fields.dart — Campos y acción de prueba para servidor PC de IA.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class RemoteServerFormFields extends StatelessWidget {
  final TextEditingController urlCtrl;
  final TextEditingController keyCtrl;
  final bool obscureKey;
  final bool testing;
  final String? testResult;
  final bool? testSuccess;
  final VoidCallback onToggleObscure;
  final VoidCallback onTestConnection;

  const RemoteServerFormFields({
    super.key,
    required this.urlCtrl,
    required this.keyCtrl,
    required this.obscureKey,
    required this.testing,
    required this.testResult,
    required this.testSuccess,
    required this.onToggleObscure,
    required this.onTestConnection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = NanoThemeExtension.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: urlCtrl,
          decoration: InputDecoration(
            labelText: 'URL del Servidor (PC / Red / VPN)',
            hintText: 'http://192.168.1.100:8080',
            prefixIcon: const Icon(Icons.link_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: keyCtrl,
          obscureText: obscureKey,
          decoration: InputDecoration(
            labelText: 'API Key (Almacenada Segura)',
            prefixIcon: const Icon(Icons.key_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: IconButton(
              icon: Icon(obscureKey ? Icons.visibility : Icons.visibility_off),
              onPressed: onToggleObscure,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: Por cable USB usa `adb reverse tcp:8080 tcp:8080`. Por Wi-Fi o VPN usa la IP de tu PC.',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: testing ? null : onTestConnection,
          icon: testing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.network_check_rounded),
          label: Text(testing ? 'Comprobando…' : 'Probar Conexión'),
        ),
        if (testResult != null) ...[
          const SizedBox(height: 8),
          Text(
            testResult!,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: testSuccess == true ? Colors.greenAccent.shade700 : theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
