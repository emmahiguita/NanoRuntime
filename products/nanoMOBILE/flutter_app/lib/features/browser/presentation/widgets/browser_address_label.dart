// QUÉ: Etiqueta y distintivos de seguridad HTTP/HTTPS para la barra de dirección.
// CÓMO: Renderiza indicador de candado/alerta y host con chip 'http://' en conexiones inseguras.
// POR QUÉ: Extraído de BrowserAddressField para respetar el límite estricto de 200 líneas (< 100 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'browser_address_formatter.dart';

class BrowserAddressLabel extends StatelessWidget {
  final BrowserAddressSecurityInfo info;
  final bool isDark;

  const BrowserAddressLabel({
    super.key,
    required this.info,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (info.displayHost.isEmpty) {
      return Text(
        'Buscar o ingresar dirección web',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.5,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (info.isInsecureHttp) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                width: 0.7,
              ),
            ),
            child: const Text(
              'http://',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            info.displayHost,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  /// Genera el icono de seguridad según el estado HTTPS/HTTP o edición.
  static Widget buildIcon({
    required bool isEditing,
    required BrowserAddressSecurityInfo info,
    required Color activeColor,
    required bool isDark,
  }) {
    if (isEditing) {
      return Icon(CupertinoIcons.search, size: 15, color: activeColor);
    }
    if (info.isInsecureHttp) {
      return const Icon(
        CupertinoIcons.exclamationmark_triangle_fill,
        size: 14.5,
        color: Color(0xFFF59E0B),
      );
    }
    if (info.isSecure) {
      return Icon(CupertinoIcons.lock_fill, size: 13.5, color: activeColor);
    }
    return Icon(
      CupertinoIcons.globe,
      size: 14,
      color: isDark ? Colors.white60 : Colors.black45,
    );
  }
}
