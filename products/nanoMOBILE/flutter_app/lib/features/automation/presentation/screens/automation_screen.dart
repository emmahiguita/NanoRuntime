import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import '../agent_console_section.dart';
import '../notification_automation_section.dart';

/// Pantalla DEDICADA de Automatización.
///
/// La automatización es un apartado propio del producto — NO vive en Ajustes.
/// Reúne la consola del agente (AgentConsoleSection) y la automatización de
/// notificaciones (NotificationAutomationSection), ambas del módulo
/// `features/automation/`.
class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});

  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: NanoAmbientBackground()),
          SafeArea(
            child: NanoScreenShell(
              title: 'Automatización',
              body: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  NanoSpacing.md,
                  NanoSpacing.md,
                  NanoSpacing.md,
                  NanoSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AgentConsoleSection(),
                    SizedBox(height: NanoSpacing.xl),
                    NotificationAutomationSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
