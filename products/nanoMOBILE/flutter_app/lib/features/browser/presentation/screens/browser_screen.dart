import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/browser_surface_notifier.dart';
import '../widgets/browser_window_widget.dart';

/// Pantalla completa del Navegador Web Real de Nano AI.
///
/// Aloja el [BrowserWindowWidget] en modo expandido con soporte para gestos atrás
/// y navegación a /dashboard.
class BrowserScreen extends ConsumerStatefulWidget {
  final String? initialUrl;
  const BrowserScreen({super.key, this.initialUrl});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  bool _surfaceReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // First detach the embedded host. Only then may the fullscreen route
      // attach the keep-alive WebViews, avoiding two native owners at once.
      ref.read(browserSurfaceProvider.notifier).showFullscreen();
      setState(() => _surfaceReady = true);
    });
  }

  @override
  void dispose() {
    ref.read(browserSurfaceProvider.notifier).showEmbedded();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final topInset = mq.padding.top > 0 ? mq.padding.top : mq.viewPadding.top;
    final bottomInset = mq.padding.bottom > 0
        ? mq.padding.bottom
        : mq.viewPadding.bottom;

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
                  left: isLandscape ? 12 + mq.padding.left : 12,
                  right: isLandscape ? 12 + mq.padding.right : 12,
                  bottom: (isLandscape ? 6 : 12) + bottomInset,
                ),
                child: _surfaceReady
                    ? BrowserWindowWidget(
                        isEmbedded: false,
                        initialUrl: widget.initialUrl,
                        onClose: () {
                          if (context.canPop()) {
                            context.pop();
                          } else if (context.mounted) {
                            context.go('/dashboard');
                          }
                        },
                      )
                    : const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
