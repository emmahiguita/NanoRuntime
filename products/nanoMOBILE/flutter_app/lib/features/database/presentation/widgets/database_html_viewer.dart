// QUÉ: visor HTML interno para reportes generados por Data Studio.
// CÓMO: lee el archivo local y lo carga como documento aislado en WebView.
// POR QUÉ: permite revisar el resultado sin abandonar NanoAI ni publicar datos.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

abstract final class DatabaseHtmlViewer {
  static Future<void> show(BuildContext context, String path) async {
    final html = await File(path).readAsString();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: Material(
          color: const Color(0xFF07111F),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
                child: Row(
                  children: [
                    const Icon(Icons.html_rounded, color: Color(0xFF5EEAD4)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        path.split(RegExp(r'[/\\]')).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
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
            ],
          ),
        ),
      ),
    );
  }
}
