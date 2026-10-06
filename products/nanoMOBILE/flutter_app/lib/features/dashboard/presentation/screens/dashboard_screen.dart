import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart'
    show notificationEventRouterProvider, timeTickSchedulerProvider;
import 'package:nanoai/features/automation/presentation/screens/automation_screen.dart';

// ════════════════════════════════════════════════════════════════════
// DASHBOARD SCREEN — Centro principal de Automatización y Agentes en Shell
// ════════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WA-PHYS-11: el dashboard (siempre montado en la shell) mantiene VIVO el
    // pipeline de reglas (NotificationEventRouter → dedupe → RuleEngine →
    // dispatcher). Verificado en dispositivo: sin un consumidor permanente
    // ningún provider instancia el router y las reglas nunca procesan
    // notificaciones reales.
    ref.watch(notificationEventRouterProvider);
    // TRIG-01: mismo consumidor permanente para el ticker de reloj — las
    // reglas de hora (TimeTrigger) disparan mientras la app esté viva.
    ref.watch(timeTickSchedulerProvider);

    return const AutomationScreen(isEmbeddedInShell: true);
  }
}
