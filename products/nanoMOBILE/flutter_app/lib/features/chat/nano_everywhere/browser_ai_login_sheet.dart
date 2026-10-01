// browser_ai_login_sheet.dart
// QUÉ HACE: Modal Material Expressive para seleccionar e iniciar sesión en proveedores de IA web.
// CÓMO FUNCIONA: Presenta los proveedores registrados, abre la pestaña en segundo plano y espera confirmación.
// POR QUÉ: Evita bloqueos y timeouts silenciosos guiando al usuario de forma clara y adaptativa (vertical y horizontal).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../browser_ai/application/browser_ai_gateway.dart';
import '../../browser_ai/application/browser_ai_provider_registry.dart';
import '../../browser_ai/domain/browser_ai_provider.dart';

/// QUÉ HACE: Despliega el BottomSheet modal para autenticación con el chat de IA.
/// CÓMO FUNCIONA: Configura el modal como deslizable, con soporte de teclado y safe area.
/// POR QUÉ: Permite autenticarse por primera vez con una cuenta secundaria en el navegador integrado.
Future<bool> showBrowserAiLoginSheet(BuildContext context, {String? suggestedProviderId}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BrowserAiLoginSheet(suggestedProviderId: suggestedProviderId),
  );
  return result ?? false;
}

class _BrowserAiLoginSheet extends ConsumerStatefulWidget {
  const _BrowserAiLoginSheet({this.suggestedProviderId});
  final String? suggestedProviderId;

  @override
  ConsumerState<_BrowserAiLoginSheet> createState() => _BrowserAiLoginSheetState();
}

class _BrowserAiLoginSheetState extends ConsumerState<_BrowserAiLoginSheet> {
  late String _selectedId;
  bool _awaitingLogin = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.suggestedProviderId ?? 'deepseek';
  }

  // QUÉ HACE: Invoca la apertura o enfoque de la pestaña del proveedor seleccionado.
  // CÓMO FUNCIONA: Llama a openProviderTab en BrowserAiGateway mediante Riverpod.
  // POR QUÉ: Prepara la sesión en el WebView integrado sin recargar ni perder cookies.
  Future<void> _openLoginTab() async {
    setState(() => _awaitingLogin = true);
    await ref.read(browserAiGatewayProvider).openProviderTab(_selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height || size.height < 500;
    final providers = ref.read(browserAiProviderRegistryProvider).allProviders;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(isLandscape ? 20 : 28)),
      ),
      padding: EdgeInsets.only(
        left: isLandscape ? 20 : 24,
        right: isLandscape ? 20 : 24,
        top: isLandscape ? 10 : 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + (isLandscape ? 12 : 20),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Material Expressive
            Center(
              child: Container(
                width: isLandscape ? 24 : 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 10 : 16),
            Text('Conectar con IA', style: isLandscape ? theme.textTheme.titleMedium : theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Inicia sesión con una cuenta secundaria o que uses poco. Las cookies se guardan solo en este dispositivo.',
              style: (isLandscape ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            SizedBox(height: isLandscape ? 10 : 16),
            // Chips de proveedores con ajuste en wrap
            Wrap(
              spacing: isLandscape ? 6 : 8,
              runSpacing: isLandscape ? 6 : 8,
              children: providers.map((p) => _ProviderChip(
                provider: p,
                selected: _selectedId == p.id,
                compact: isLandscape,
                onTap: () => setState(() {
                  _selectedId = p.id;
                  _awaitingLogin = false;
                }),
              )).toList(),
            ),
            SizedBox(height: isLandscape ? 14 : 20),
            if (!_awaitingLogin)
              FilledButton.icon(
                onPressed: _openLoginTab,
                icon: Icon(Icons.open_in_browser_rounded, size: isLandscape ? 18 : 20),
                label: const Text('Abrir pestaña de login'),
                style: FilledButton.styleFrom(minimumSize: Size.fromHeight(isLandscape ? 40 : 48)),
              )
            else ...[
              Container(
                padding: EdgeInsets.all(isLandscape ? 10 : 14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: cs.onPrimaryContainer, size: isLandscape ? 18 : 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Inicia sesión en la pestaña y pulsa "Listo" para reanudar.',
                        style: (isLandscape ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(isLandscape ? 40 : 48),
                  backgroundColor: cs.primary,
                ),
                child: const Text('Listo, ya inicié sesión'),
              ),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: Size.fromHeight(isLandscape ? 36 : 42)),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

// QUÉ HACE: Chip visual individual para seleccionar un proveedor de IA.
// CÓMO FUNCIONA: Utiliza FilterChip de Material 3 con estados visuales claros y soporte compacto.
// POR QUÉ: Principio de Responsabilidad Única (SRP) aislando el renderizado de cada opción.
class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.provider,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final BrowserAiProvider provider;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(
        provider.displayName,
        style: TextStyle(
          fontSize: compact ? 12 : 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      onSelected: (_) => onTap(),
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.onPrimaryContainer,
    );
  }
}
