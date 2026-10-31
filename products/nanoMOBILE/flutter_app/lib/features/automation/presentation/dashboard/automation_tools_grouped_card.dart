// automation_tools_grouped_card.dart — Lista abierta de Herramientas sin card.
// QUÉ HACE:
// Despliega todas las herramientas en una lista abierta que aprovecha al máximo el ancho
// de pantalla, con micro-cápsulas de cristal para los iconos y separadores físicos de 1px.
//
// CÓMO FUNCIONA:
// Renderiza filas en Column directa con divisores alineados al inicio del texto.
//
// POR QUÉ:
// Satisface la eliminación de la card contenedora en Herramientas (< 120 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';
import 'automation_row_item.dart';

class AutomationToolsGroupedCard extends StatelessWidget {
  const AutomationToolsGroupedCard({
    super.key,
    this.onMcpTap,
    this.onAiWebTap,
    this.onChatTap,
    this.onWhatsAppWebTap,
    this.onBrowserTap,
    this.onTerminalTap,
    this.onSettingsTap,
  });

  final VoidCallback? onMcpTap;
  final VoidCallback? onAiWebTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onWhatsAppWebTap;
  final VoidCallback? onBrowserTap;
  final VoidCallback? onTerminalTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final dividerThickness = 1.0 / (pixelRatio > 0 ? pixelRatio : 1.0);
    final dividerColor = visual.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    Widget buildDivider() => Divider(
      height: dividerThickness,
      thickness: dividerThickness,
      indent: 52,
      endIndent: 4,
      color: dividerColor,
    );

    final tools = <Widget>[
      AutomationRowItem(
        icon: CupertinoIcons.link,
        title: 'Conexiones y API',
        subtitle: 'Proveedores, claves y MCP',
        onTap: onMcpTap,
      ),
      buildDivider(),
      AutomationRowItem(
        icon: CupertinoIcons.square_on_square,
        title: 'Sesiones IA',
        subtitle: 'Servicios en ventanas flotantes',
        onTap: onAiWebTap,
      ),
      buildDivider(),
      AutomationRowItem(
        icon: CupertinoIcons.chat_bubble_2,
        title: 'Chat IA',
        subtitle: 'Conversaciones con modelos y agentes',
        onTap: onChatTap,
      ),
      if (onWhatsAppWebTap != null) ...[
        buildDivider(),
        AutomationRowItem(
          icon: CupertinoIcons.chat_bubble,
          title: 'WhatsApp Web',
          subtitle: 'Automatización y sincronización web',
          onTap: onWhatsAppWebTap,
        ),
      ],
      buildDivider(),
      AutomationRowItem(
        icon: CupertinoIcons.compass,
        title: 'Navegador',
        subtitle: 'Explora la web con asistencia',
        onTap: onBrowserTap,
      ),
      if (onTerminalTap != null) ...[
        buildDivider(),
        AutomationRowItem(
          icon: CupertinoIcons.chevron_left_slash_chevron_right,
          title: 'Terminal Linux',
          subtitle: 'Comandos y entorno de ejecución',
          onTap: onTerminalTap,
        ),
      ],
      if (onSettingsTap != null) ...[
        buildDivider(),
        AutomationRowItem(
          icon: CupertinoIcons.slider_horizontal_3,
          title: 'Ajustes del sistema',
          subtitle: 'Configuración y preferencias',
          onTap: onSettingsTap,
        ),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: tools,
    );
  }
}
