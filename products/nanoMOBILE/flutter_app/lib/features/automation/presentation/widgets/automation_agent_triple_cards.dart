// automation_agent_triple_cards.dart — Lista abierta de agentes sin contenedor card.
// QUÉ HACE:
// Despliega a Nano Personal, Nano Negocio y Modelos locales en formato de lista abierta
// con separadores ultrafinos, aprovechando al máximo el ancho de pantalla.
//
// CÓMO FUNCIONA:
// Renderiza filas elásticas directamente en Column con divisores de 1px alineados al texto.
//
// POR QUÉ:
// Satisface la eliminación de la card contenedora en Tus Agentes (< 130 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';
import 'automation_agent_avatars.dart';
import 'automation_agent_list_row.dart';

class AutomationAgentTripleCards extends StatelessWidget {
  const AutomationAgentTripleCards({
    super.key,
    this.onPersonalTap,
    this.onBusinessTap,
    this.onModelsTap,
    this.onManageTap,
    this.isW4bActive = false,
  });

  final VoidCallback? onPersonalTap;
  final VoidCallback? onBusinessTap;
  final VoidCallback? onModelsTap;
  final VoidCallback? onManageTap;
  final bool isW4bActive;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final dark = visual.isDark;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final dividerThickness = 1.0 / (pixelRatio > 0 ? pixelRatio : 1.0);
    final dividerColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    Widget buildDivider() => Divider(
      height: dividerThickness,
      thickness: dividerThickness,
      indent: 58,
      endIndent: 4,
      color: dividerColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado: "Tus agentes" y "Administrar >"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Tus agentes',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: visual.text,
                ),
              ),
              if (onManageTap != null)
                Semantics(
                  button: true,
                  label: 'Administrar agentes',
                  child: InkWell(
                    onTap: onManageTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Administrar',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: visual.textMuted,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 11,
                            color: visual.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Lista abierta sin card rígida envolvente
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AutomationAgentListRow(
              avatar: AgentPersonalAvatar(size: 42, isDark: dark),
              title: 'Nano Personal',
              subtitle: 'Tu estilo y memoria',
              onTap: onPersonalTap,
            ),
            buildDivider(),
            AutomationAgentListRow(
              avatar: AgentBusinessAvatar(size: 42, isDark: dark),
              title: 'Nano Negocio',
              subtitle: 'Atención y catálogo',
              trailing: AgentStatusBadge(isActive: isW4bActive, isDark: dark),
              onTap: onBusinessTap,
            ),
            buildDivider(),
            AutomationAgentListRow(
              avatar: AgentModelsAvatar(size: 42, isDark: dark),
              title: 'Modelos locales',
              subtitle: 'Qwen y Gemma en tu dispositivo',
              onTap: onModelsTap,
            ),
          ],
        ),
      ],
    );
  }
}
