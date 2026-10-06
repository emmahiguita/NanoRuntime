import 'package:flutter/material.dart';

/// Muestra un error de almacenamiento sin filtrar rutas ni excepciones internas.
final class BusinessLibraryLoadError extends StatelessWidget {
  const BusinessLibraryLoadError({
    super.key,
    required this.busy,
    required this.onRetry,
  });

  final bool busy;
  final VoidCallback onRetry;

  // Mantiene la causa legible y ofrece una acción que recarga la biblioteca.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: colors.error),
            const SizedBox(height: 8),
            const Text('No se pudo cargar la biblioteca.'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: busy ? null : onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
