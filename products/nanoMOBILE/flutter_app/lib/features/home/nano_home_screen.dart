import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_window_widget.dart';

import 'nano_home_models.dart';

// =============================================================
// NANO HOME SCREEN — Dashboard Real con Cuenta Google & Telemetría
// =============================================================

class NanoHomeScreen extends StatelessWidget {
  final NanoTelemetryData telemetry;
  final KaliStatus kaliStatus;
  final String? chatSubtitle;
  final String? terminalSubtitle;

  final VoidCallback onTerminalTap;
  final VoidCallback onChatTap;
  final VoidCallback onModelsTap;
  final VoidCallback? onDesktopTap;
  final VoidCallback? onAutomationTap;
  final VoidCallback onKaliTap;

  /// Estados EN VIVO reales (providers)
  final bool chatOn;
  final bool termOn;
  final bool modelOn;

  const NanoHomeScreen({
    super.key,
    required this.telemetry,
    required this.kaliStatus,
    this.chatSubtitle,
    this.terminalSubtitle,
    required this.onTerminalTap,
    required this.onChatTap,
    required this.onModelsTap,
    this.onDesktopTap,
    this.onAutomationTap,
    required this.onKaliTap,
    this.chatOn = false,
    this.termOn = false,
    this.modelOn = false,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final topInset = mq.padding.top > 0 ? mq.padding.top : mq.viewPadding.top;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.only(
          top: topInset > 0 ? topInset + (isLandscape ? 2 : 4) : (isLandscape ? 6 : 8),
          bottom: isLandscape ? 2 : 6,
          left: isLandscape ? (mq.padding.left > 0 ? mq.padding.left + 4 : 8) : 4,
          right: isLandscape ? (mq.padding.right > 0 ? mq.padding.right + 4 : 8) : 4,
        ),
        child: BrowserWindowWidget(
          isEmbedded: false,
          onFullscreen: () => context.push('/browser'),
        ),
      ),
    );
  }
}
