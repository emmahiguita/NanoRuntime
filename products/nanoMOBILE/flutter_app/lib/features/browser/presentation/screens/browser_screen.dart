import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/browser_window_widget.dart';

/// Pantalla completa del Navegador Web Real de Nano AI.
///
/// Aloja el [BrowserWindowWidget] en modo expandido con soporte para gestos atrás
/// y navegación a /dashboard.
class BrowserScreen extends ConsumerWidget {
  final String? initialUrl;
  const BrowserScreen({super.key, this.initialUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final topInset = mq.padding.top > 0 ? mq.padding.top : mq.viewPadding.top;
    final bottomInset = mq.padding.bottom > 0 ? mq.padding.bottom : mq.viewPadding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else if (context.mounted) {
          context.go('/dashboard');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            SizedBox(height: topInset + (isLandscape ? 6 : 10)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: isLandscape ? 12 + mq.padding.right : 12,
                  bottom: (isLandscape ? 6 : 12) + bottomInset,
                ),
                child: BrowserWindowWidget(
                  isEmbedded: false,
                  initialUrl: initialUrl,
                  onClose: () {
                    if (context.canPop()) {
                      context.pop();
                    } else if (context.mounted) {
                      context.go('/dashboard');
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
