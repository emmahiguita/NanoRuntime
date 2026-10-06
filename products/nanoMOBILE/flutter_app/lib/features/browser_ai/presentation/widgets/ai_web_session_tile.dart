// ai_web_session_tile.dart — Tarjeta de estado y acción para un proveedor web de IA.
// QUÉ HACE: Muestra el estado de conexión (● Conectado / ○ Sin conectar) y acciones rápidas.
// CÓMO FUNCIONA: Ofrece botón de ventana flotante y menú de opciones usando Semantics sin Tooltip.
// POR QUÉ: Previene el error "No Overlay" en modales flotantes y cumple el límite de < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AiWebSessionTile extends StatelessWidget {
  final String providerId;
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
    required this.providerId,
    required this.displayName,
    required this.url,
    required this.isConnected,
    required this.isPreferred,
    required this.onConnectFloating,
    required this.onOpenExternal,
    required this.onSetPreferred,
    this.onDeleteCustom,
  });

  Color _getProviderColor() {
    switch (providerId.toLowerCase()) {
      case 'chatgpt': return const Color(0xFF10A37F);
      case 'deepseek': return const Color(0xFF0D6EFD);
      case 'gemini': return const Color(0xFF388BFD);
      case 'kimi': return const Color(0xFF26B287);
      case 'qwen': return const Color(0xFF6366F1);
      case 'claude': return const Color(0xFFD97706);
      case 'perplexity': return const Color(0xFF14B8A6);
      case 'copilot': return const Color(0xFF0078D4);
      default: return const Color(0xFFA855F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = _getProviderColor();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPreferred ? accentColor.withValues(alpha: 0.60) : theme.colorScheme.outline.withValues(alpha: 0.15),
          width: isPreferred ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
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
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPreferred) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Preferido',
                          style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? const Color(0xFF10B981) : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'Conectado' : 'Sin conectar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isConnected ? const Color(0xFF10B981) : theme.colorScheme.onSurface.withValues(alpha: 0.50),
                      ),
                    ),
                  ],
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
                color: isConnected ? const Color(0xFF10B981) : theme.colorScheme.primary,
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
                    Text('Abrir en navegador seguro', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'preferred',
                child: Row(
                  children: [
                    Icon(isPreferred ? Icons.star_rounded : Icons.star_border_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(isPreferred ? 'Quitar preferido' : 'Marcar preferido', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              if (onDeleteCustom != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
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
