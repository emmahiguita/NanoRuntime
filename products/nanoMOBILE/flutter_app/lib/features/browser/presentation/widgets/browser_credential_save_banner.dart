import 'package:flutter/material.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_tab_bar_widget.dart';

/// Banner flotante animado para solicitar al usuario guardar credenciales al iniciar sesión.
class BrowserCredentialSaveBanner extends StatelessWidget {
  final String domain;
  final String username;
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  const BrowserCredentialSaveBanner({
    super.key,
    required this.domain,
    required this.username,
    required this.onSave,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFA0B1626),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
              border: Border.all(
                color: const Color(0xFF38BDF8),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              BrowserTabBarWidget.getBrandIcon(domain),
              size: 17,
              color: const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.vpn_key_rounded, size: 12, color: Color(0xFF38BDF8)),
                    SizedBox(width: 4),
                    Text(
                      '¿Guardar contraseña?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$domain${username.isNotEmpty ? ' • $username' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(50, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'No ahora',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
            ),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Guardar',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
