// Error visual del Centro: explica la acción siguiente sin exponer excepciones nativas.
import 'package:flutter/material.dart';

/// Reemplaza códigos de plataforma por un mensaje accionable para la persona.
final class MessagingErrorCard extends StatelessWidget {
  const MessagingErrorCard({
    super.key,
    required this.error,
    required this.onRetry,
  });
  final Object error;
  final VoidCallback onRetry;

  // Los errores del canal nativo se registran en Android; aquí se explica cómo continuar.
  String _message() {
    final detail = error.toString();
    if (detail.contains('MissingPluginException') ||
        detail.contains('com.nanoai/automation_store')) {
      return 'Nano no pudo conectar con el historial local. Reintenta; si persiste, cierra y abre Nano.';
    }
    return 'No se pudieron cargar las conversaciones. Comprueba el acceso y vuelve a intentar.';
  }

  // Usa el esquema activo para que la alerta sea legible en tema claro y oscuro.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(16),
      color: colors.errorContainer.withValues(alpha: .32),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.error.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: colors.error, size: 26),
            const SizedBox(height: 8),
            Text(
              _message(),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurface, fontSize: 13),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
