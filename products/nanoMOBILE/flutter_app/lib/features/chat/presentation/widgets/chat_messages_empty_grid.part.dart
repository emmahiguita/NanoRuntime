part of 'chat_messages.dart';

/// QUÉ HACE: muestra tareas reales del chat en una cuadrícula adaptable al ancho.
class _EmptyChatQuickActionGrid extends StatelessWidget {
  const _EmptyChatQuickActionGrid({required this.onSuggestion});

  final void Function(String) onSuggestion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isNarrow ? 1 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isNarrow ? 3.4 : 2.2,
          children: [
            _QuickCard(
              icon: Icons.battery_charging_full_rounded,
              iconColor: const Color(0xFF00E676),
              title: 'Estado del Hardware',
              subtitle: 'Batería, RAM y CPU con Memento Fast-Path',
              onTap: () => onSuggestion(
                '¿Cómo está la batería y el hardware del teléfono?',
              ),
            ),
            _QuickCard(
              icon: Icons.speed_rounded,
              iconColor: const Color(0xFF00B0FF),
              title: 'Benchmark & TPS',
              subtitle: 'Evalúa rendimiento local y tokens/segundo',
              onTap: () => onSuggestion(
                'Realiza una prueba de estrés y análisis de rendimiento de inferencia. '
                'Organiza los resultados en una tabla comparativa con métricas de RAM, CPU y TPS.',
              ),
            ),
            _QuickCard(
              icon: Icons.description_rounded,
              iconColor: const Color(0xFFFF9100),
              title: 'Informe Técnico en PDF',
              subtitle: 'Genera un reporte estructurado y compártelo',
              onTap: () => onSuggestion(
                'Genera un informe técnico completo y estructurado sobre el estado actual del dispositivo, '
                'con tablas detalladas de arquitectura y almacenamiento, listo para exportar a PDF.',
              ),
            ),
            _QuickCard(
              icon: Icons.account_tree_rounded,
              iconColor: const Color(0xFFE040FB),
              title: 'Diagrama de Arquitectura',
              subtitle: 'Visualiza el stack local con código Mermaid',
              onTap: () => onSuggestion(
                'Explica la arquitectura del runtime de NanoAI (Flutter, Binder/SAF, nanortime, llama.cpp) '
                'e incluye un diagrama en bloque de código ```mermaid.',
              ),
            ),
          ],
        );
      },
    );
  }
}
