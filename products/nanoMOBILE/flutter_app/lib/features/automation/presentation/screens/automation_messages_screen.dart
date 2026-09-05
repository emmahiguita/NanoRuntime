import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';

import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import '../notification_automation_section.dart';

/// Función de USUARIO (no Dev): responder mensajes y notificaciones.
///
/// Reúne la capacidad de `NotificationExecutor` (consultar notificaciones,
/// detectar cuáles pueden responderse, generar borrador local, editarlo,
/// confirmar y enviar desde Android) en una pantalla principal, fuera de las
/// herramientas técnicas de Dev.
class AutomationMessagesScreen extends ConsumerWidget {
  const AutomationMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualMode = AutomationVisual.modeFromSetting(
      ref.watch(settingsProvider.select((settings) => settings.themeMode)),
    );
    return Theme(
      data: AutomationVisual.theme(context, mode: visualMode),
      child: const _AutomationMessagesBody(),
    );
  }
}

class _AutomationMessagesBody extends StatelessWidget {
  const _AutomationMessagesBody();

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
        // NAV-BAR-FIX-03 — barra global también en Mensajes.
        body: NanoShellBarScope(
          child: Stack(
          fit: StackFit.expand,
          children: [
            // UI-REV-03: fondo compartido del módulo.
            const AutomationBackdrop(),
            SafeArea(
              child: NanoScreenShell(
                title: 'Mensajes y notificaciones',
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
                      // UI-REV-13: ancho adaptativo (720 vertical / 1080
                      // horizontal) — punto único en AutomationLayout.
                      constraints: BoxConstraints(
                        maxWidth: AutomationLayout.contentMaxWidth(context),
                      ),
                      child: const NotificationAutomationSection(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
