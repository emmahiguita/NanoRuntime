// QUÉ: Encabezado del menú flotante de opciones de Nano Browser.
// CÓMO: Muestra el indicador HTTPS/escudo de seguridad, dominio actual y botón de cierre iOS.
// POR QUÉ: Extraído de BrowserOptionsSheet para Clean Architecture y mantener archivos < 200 líneas.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BrowserOptionsHeader extends StatelessWidget {
  final String domain;
  final bool isSecure;
  final bool isDark;

  const BrowserOptionsHeader({
    super.key,
    required this.domain,
    required this.isSecure,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF2563EB).withValues(alpha: 0.4),
                        const Color(0xFF38BDF8).withValues(alpha: 0.2),
                      ]
                    : [const Color(0xFFDBEAFE), const Color(0xFFEFF6FF)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
                    : const Color(0xFF93C5FD),
              ),
            ),
            child: Icon(
              isSecure ? CupertinoIcons.lock_shield_fill : CupertinoIcons.globe,
              size: 18,
              color: isSecure
                  ? const Color(0xFF38BDF8)
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opciones del navegador',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context, rootNavigator: true).pop();
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 13,
                  color: isDark ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
