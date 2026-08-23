import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';

import '../widgets/automation_dashboard.dart';
import 'automation_dev_screen.dart';

/// El centro de control operativo de NanoAutomation.
///
/// NO es una consola de debugging: es el dashboard del asistente. Muestra
/// estado + composer + quick actions + capacidades + ejecuciones recientes.
/// Las herramientas técnicas viven en la pantalla Dev (icono en el header).
/// Solo un botón atrás (NanoScreenShell, auto) — sin panel de navegación.
class AutomationScreen extends ConsumerWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: NanoAmbientBackground()),
          SafeArea(
            child: NanoScreenShell(
              title: 'Automatización',
              trailing: IconButton(
                tooltip: 'Dev',
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AutomationDevScreen(),
                  ),
                ),
                icon: Icon(Icons.build_circle_rounded,
                    color: colors.onSurfaceVariant),
              ),
              body: const AutomationDashboard(),
            ),
          ),
        ],
      ),
    );
  }
}
