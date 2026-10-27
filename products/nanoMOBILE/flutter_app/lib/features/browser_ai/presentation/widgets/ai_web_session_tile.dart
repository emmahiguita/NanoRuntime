// ai_web_session_tile.dart — Tarjeta de estado y acción para un proveedor web de IA.
// QUÉ HACE: Muestra el estado de conexión (● Conectado / ○ Sin conectar) y acciones rápidas.
// CÓMO FUNCIONA: Ofrece botón de ventana flotante y menú de opciones usando Semantics sin Tooltip.
// POR QUÉ: Previene el error "No Overlay" en modales flotantes y cumple el límite de < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/nano_status_badge.dart';
import 'ai_web_provider_icon.dart';

class AiWebSessionTile extends StatelessWidget {
  final String displayName;
  final String url;
  final bool isConnected;
  final bool isPreferred;
  final VoidCallback onConnectFloating;
  final VoidCallback onOpenExternal;
  final VoidCallback onSetPreferred;
  final VoidCallback? onDeleteCustom;

  const AiWebSessionTile({
    super.key,
    required this.displayName,
    required this.url,
    required this.isConnected,
    required this.isPreferred,
    required this.onConnectFloating,
    required this.onOpenExternal,
    required this.onSetPreferred,
    this.onDeleteCustom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    // Verifica el dominio del servicio; un proveedor personalizado llamado Qwen no basta.
    final isQwen = AiWebProviderIcon.isQwenUrl(url);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPreferred
              ? accentColor.withValues(alpha: 0.60)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
          width: isPreferred ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          AiWebProviderIcon(name: displayName, url: url),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPreferred) ...[
                      const SizedBox(width: 6),
                      NanoStatusBadge(
                        label: 'Preferido',
                        indicatorColor: theme.colorScheme.primary,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                NanoStatusBadge(
                  label: isConnected ? 'Conectado' : 'Sin conectar',
                  indicatorColor: isConnected
                      ? theme.colorScheme.tertiary
                      : null,
                  compact: true,
                ),
                if (isQwen)
                  Text(
                    'Servicio web · requiere Internet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: isConnected ? 'Abrir ventana flotante' : 'Conectar sesión',
            child: IconButton(
              icon: Icon(
                isConnected ? Icons.open_in_new_rounded : Icons.login_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                onConnectFloating();
              },
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 19),
            onSelected: (val) {
              if (val == 'external') onOpenExternal();
              if (val == 'preferred') onSetPreferred();
              if (val == 'delete') onDeleteCustom?.call();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'external',
                child: Row(
                  children: [
                    Icon(Icons.launch_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Abrir en navegador seguro',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'preferred',
                child: Row(
                  children: [
                    Icon(
                      isPreferred
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPreferred ? 'Quitar preferido' : 'Marcar preferido',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (onDeleteCustom != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
