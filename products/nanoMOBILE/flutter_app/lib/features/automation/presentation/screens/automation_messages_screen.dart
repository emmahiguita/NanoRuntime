import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/liquid_fluid_background.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';

import '../notification_automation_section.dart';

/// Función de USUARIO (no Dev): responder mensajes y notificaciones.
///
/// Reúne la capacidad de `NotificationExecutor` (consultar notificaciones,
/// detectar cuáles pueden responderse, generar borrador local, editarlo,
/// confirmar y enviar desde Android) en una pantalla principal, fuera de las
/// herramientas técnicas de Dev.
class AutomationMessagesScreen extends StatelessWidget {
  const AutomationMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lógica real de retroceso: si hay una ruta padre (entró por push), el
    // gesto atrás hace pop natural; si no (enlace directo/deep-link), el gesto
    // reenvía a /automation en lugar de cerrar la app.
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/automation');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: LiquidFluidBackground()),
            SafeArea(
              child: NanoScreenShell(
                title: 'Mensajes',
                showBack: true,
                body: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    NanoSpacing.md,
                    NanoSpacing.md,
                    NanoSpacing.md,
                    NanoSpacing.xxxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: const NotificationAutomationSection(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
