// QUÉ: visor HTML interno para reportes generados por Data Studio.
// CÓMO: lee el archivo local y lo carga como documento aislado en WebView.
// POR QUÉ: permite revisar el resultado sin abandonar NanoAI ni publicar datos.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

abstract final class DatabaseHtmlViewer {
  static Future<void> show(BuildContext context, String path) async {
    final html = await File(path).readAsString();
    if (!context.mounted) return;
    await showNanoGlassWindow<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.html_rounded, color: Color(0xFF5EEAD4)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      path.split(RegExp(r'[/\\]')).last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                child: InAppWebView(
                  initialData: InAppWebViewInitialData(
                    data: html,
                    baseUrl: WebUri('file:///'),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: false,
                    allowFileAccess: false,
                    allowContentAccess: false,
                    supportZoom: true,
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
