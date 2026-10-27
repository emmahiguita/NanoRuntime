import 'package:flutter/material.dart';
import 'browser_load_error_description.dart';

/// Recuperación real de carga: mantiene la dirección y acciones existentes.
/// No promete disponibilidad de una página ni sustituye errores por simulaciones.
class BrowserErrorView extends StatelessWidget {
  final String url;
  final String? errorMessage;
  final int? errorCode;
  final VoidCallback onRetry;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onGoHome;
  const BrowserErrorView({
    super.key,
    required this.url,
    this.errorMessage,
    this.errorCode,
    required this.onRetry,
    required this.onNavigate,
    this.onGoHome,
  });

  /// El buscador recibe el dominio completo, no solo la parte antes del primer punto.
  void _search() {
    final host = Uri.tryParse(url)?.host ?? '';
    onNavigate(
      Uri.https('www.google.com', '/search', {
        'q': host.isEmpty ? url : host,
      }).toString(),
    );
  }

  /// Desplazamiento y Wrap evitan botones desbordados con poco alto o letras grandes.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = Uri.tryParse(url)?.host ?? '';
    return Material(
      color: theme.colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'No se pudo cargar la página',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  host.isEmpty ? url : host,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  BrowserLoadErrorDescription.describe(errorMessage, errorCode),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _search,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Buscar sitio'),
                    ),
                    if (onGoHome != null)
                      TextButton(
                        onPressed: onGoHome,
                        child: const Text('Inicio del navegador'),
                      ),
                  ],
                ),
                if ((errorMessage ?? '').isNotEmpty || errorCode != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Detalles del error'),
                    children: [
                      SelectableText(
                        [
                          if (errorCode != null) 'Código: $errorCode',
                          if ((errorMessage ?? '').isNotEmpty) errorMessage!,
                        ].join('\n'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
