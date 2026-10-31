// automation_agent_card_content.dart — Contenido textual y chevrons para tarjetas de agentes.
// QUÉ HACE: Despliega el título con sombra tipográfica, subtítulo o badge y el chevron de navegación.
// CÓMO FUNCIONA: Posiciona elementos sobre la superficie visual garantizando contraste WCAG.
// POR QUÉ: Satisface la modularidad y mantiene cada archivo bajo el límite de 200 líneas.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AgentCardChevron extends StatelessWidget {
  const AgentCardChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.chevron_right,
          size: 10,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class AgentCardFooter extends StatelessWidget {
  const AgentCardFooter({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
  });

  final String title;
  final String? subtitle;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 7.5,
      right: 7.5,
      bottom: 6.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.15,
              color: Colors.white,
              letterSpacing: -0.3,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          if (badge != null)
            badge!
          else if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w400,
                height: 1.15,
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: -0.2,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
