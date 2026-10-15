/// Restaura la sesión vinculada al abrir Mensajería, sin navegar a la ruta Web.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';
import '../whatsapp_web/whatsapp_web_adapter.dart';
import '../whatsapp_web/whatsapp_web_session_ownership.dart';
import '../whatsapp_web/widgets/whatsapp_web_view_container.dart';
import 'whatsapp_web_feed_provider.dart';

class WhatsAppWebBackgroundHost extends ConsumerWidget {
  const WhatsAppWebBackgroundHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(whatsappWebFeedEnabledProvider).valueOrNull == true;
    return ValueListenableBuilder<bool>(
      valueListenable: WhatsAppWebSessionOwnership.foreground,
      builder: (_, visible, _) {
        if (!enabled || visible) return const SizedBox.shrink();
        // Detrás del fondo opaco del panel: mantiene dimensiones reales para
        // el DOM virtualizado, pero no recibe toques, foco ni accesibilidad.
        return ExcludeFocus(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: WhatsAppWebViewContainer(
                keepAlive: WhatsAppWebSessionOwnership.keepAlive,
                hasCreatedPersistentWebView:
                    WhatsAppWebSessionOwnership.created,
                onWebViewCreated: (controller) {
                  WhatsAppWebSessionOwnership.created = true;
                  whatsAppWebBridgeController.attachController(controller);
                  // Restaurar no equivale a recargar: usa el documento retenido.
                  unawaited(
                    controller.getUrl().then((url) {
                      if (url != null &&
                          WhatsAppWebAdapter.isAllowedUrl('$url')) {
                        return whatsAppWebBridgeController.onPageFinished(
                          '$url',
                        );
                      }
                    }),
                  );
                },
                onLoadStop: (_, url) {
                  if (url != null && WhatsAppWebAdapter.isAllowedUrl('$url')) {
                    unawaited(
                      whatsAppWebBridgeController.onPageFinished('$url'),
                    );
                  }
                },
                onProgressChanged: (_) {},
              ),
            ),
          ),
        );
      },
    );
  }
}
