import 'package:flutter/material.dart';
import '../../automation_visual_theme.dart';

/// QUÉ HACE:
/// Banner visual de cabecera para el Agente Personal de WhatsApp.
///
/// CÓMO FUNCIONA:
/// Muestra un contenedor estilizado con gradiente de fondo, el icono de la
/// marca WhatsApp Personal y el texto descriptivo de identidad.
///
/// POR QUÉ:
/// Desacopla el encabezado decorativo de la pantalla principal (SRP de SOLID)
/// manteniendo el archivo principal por debajo de 200 líneas de código.
class PersonalAgentHeaderBanner extends StatelessWidget {
  const PersonalAgentHeaderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            visual.accent.withValues(alpha: 0.16),
            visual.surface.withValues(alpha: 0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: visual.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: visual.accent.withValues(alpha: 0.4),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/automation/whatsapp_personal_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agente Personal WPP',
                  style: TextStyle(
                    color: visual.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Respuestas privadas, identidad y estilo de comunicación',
                  style: TextStyle(
                    color: visual.isDark
                        ? const Color(0xFFBAC5D4)
                        : visual.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
