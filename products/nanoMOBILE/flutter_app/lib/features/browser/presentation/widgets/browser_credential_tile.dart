import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/browser/domain/browser_credential_model.dart';
import 'browser_tab_bar_widget.dart';

/// Tarjeta individual para mostrar una credencial en la bóveda (Liquid Glass).
///
/// Principio SOLID: Responsabilidad Única (SRP) - Renderizado y gestión de interacciones
/// visuales de una sola credencial (copiado, revelado de contraseña y eliminación).
class BrowserCredentialTile extends StatelessWidget {
  final BrowserCredential credential;
  final bool isRevealed;
  final bool isCurrentSite;
  final VoidCallback onToggleReveal;
  final void Function(String username, String password)? onAutofill;
  final VoidCallback onDelete;

  const BrowserCredentialTile({
    super.key,
    required this.credential,
    required this.isRevealed,
    required this.isCurrentSite,
    required this.onToggleReveal,
    this.onAutofill,
    required this.onDelete,
  });

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentSite ? const Color(0xFF0F2338) : const Color(0xFF131D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentSite
              ? const Color(0xFF0284C7).withValues(alpha: 0.7)
              : const Color(0xFF1E293B),
          width: isCurrentSite ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Favicon, Dominio, Botón Rellenar y Eliminar
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1E293B),
                ),
                alignment: Alignment.center,
                child: Icon(
                  BrowserTabBarWidget.getBrandIcon(credential.domain),
                  size: 13,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  credential.domain,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isCurrentSite && onAutofill != null)
                InkWell(
                  onTap: () => onAutofill!(credential.username, credential.password),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 13),
                        SizedBox(width: 3),
                        Text(
                          'Rellenar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fila de Usuario con botón de copiado rápido
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  credential.username,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => _copyToClipboard(
                  context,
                  credential.username,
                  'Usuario copiado al portapapeles',
                ),
              ),
            ],
          ),

          // Fila de Contraseña con botón de revelado y copiado
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isRevealed ? credential.password : '••••••••••••',
                  style: TextStyle(
                    color: isRevealed ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontFamily: isRevealed ? 'monospace' : null,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 15,
                  color: const Color(0xFF94A3B8),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: onToggleReveal,
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => _copyToClipboard(
                  context,
                  credential.password,
                  'Contraseña copiada al portapapeles',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
