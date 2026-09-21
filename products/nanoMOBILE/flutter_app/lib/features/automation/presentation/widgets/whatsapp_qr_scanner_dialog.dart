/// WA-QR-SCANNER-01 — Diálogo de escaneo QR e inspección directa en Nano.
///
/// **QUÉ HACE:**
/// Extrae la imagen nítida del Canvas/DOM o captura nativa, decodifica con ML Kit
/// y permite compartir a Google Lens o copiar el código de 8 dígitos de vinculación.
///
/// **CÓMO FUNCIONA:**
/// Pasa los bytes nítidos a ML Kit `BarcodeScanning`, FileProvider y `SharePlus`.
///
/// **POR QUÉ:**
/// Elimina las obstrucciones de pantalla y garantiza que Google Lens y la galería lean el QR.
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/whatsapp_media_payload.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';

class WhatsAppQrScannerDialog extends StatefulWidget {
  const WhatsAppQrScannerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WhatsAppQrScannerDialog(),
    );
  }

  @override
  State<WhatsAppQrScannerDialog> createState() => _WhatsAppQrScannerDialogState();
}

class _WhatsAppQrScannerDialogState extends State<WhatsAppQrScannerDialog> {
  Uint8List? _screenshotBytes, _domQrBytes;
  String? _decodedQrText;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _fetchNativeScreenshot();
  }

  Future<void> _fetchNativeScreenshot() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    final session = whatsAppWebBridgeController.currentSession;
    Uint8List? domBytes;
    if (session.qrDataUrl != null && session.qrDataUrl!.contains(',')) {
      try { domBytes = base64Decode(session.qrDataUrl!.split(',').last); } catch (_) {}
    }
    final screenBytes = await whatsAppWebBridgeController.captureScreen();
    final bytesToScan = domBytes ?? screenBytes;
    String? decoded = session.qrDataRef;
    if ((decoded == null || decoded.isEmpty) && bytesToScan != null && bytesToScan.isNotEmpty) {
      try {
        final res = await const MethodChannel('com.nanoai/agent').invokeMethod('scanQr', {'png': bytesToScan});
        if (res is List && res.isNotEmpty) {
          decoded = (Map<String, dynamic>.from(res.first as Map))['rawValue'] as String?;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _domQrBytes = domBytes;
        _screenshotBytes = screenBytes;
        _decodedQrText = decoded;
        _isCapturing = false;
      });
    }
  }

  Future<Uint8List?> _getBestQrBytes() async {
    if (_domQrBytes != null && _domQrBytes!.isNotEmpty) return _domQrBytes;
    final session = whatsAppWebBridgeController.currentSession;
    if (session.qrDataUrl != null && session.qrDataUrl!.contains(',')) {
      try { return base64Decode(session.qrDataUrl!.split(',').last); } catch (_) {}
    }
    return _screenshotBytes ?? await whatsAppWebBridgeController.captureScreen();
  }

  Future<void> _openGoogleLens() async {
    final bytes = await _getBestQrBytes();
    if (bytes == null || bytes.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nano_whatsapp_qr.png');
      await file.writeAsBytes(bytes);
      final ok = await const MethodChannel('com.nanoai/agent').invokeMethod('openGoogleLens', {'filePath': file.path});
      if (ok != true) await _shareQrImage();
    } catch (_) { await _shareQrImage(); }
  }

  Future<void> _shareQrImage() async {
    final bytes = await _getBestQrBytes();
    if (bytes == null || bytes.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nano_whatsapp_qr.png');
      await file.writeAsBytes(bytes);
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'Código QR Nano');
    } catch (_) {}
  }

  Future<void> _copyPairingCode() async {
    final messenger = ScaffoldMessenger.of(context);
    final code = await whatsAppWebBridgeController.getPairingCode();
    if (code != null && code.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: code));
      messenger.showSnackBar(SnackBar(content: Text('¡Código $code copiado! Pégalo en WhatsApp.')));
    } else {
      await whatsAppWebBridgeController.switchToPhoneLinking();
      messenger.showSnackBar(const SnackBar(content: Text('Ingresa tu teléfono en WhatsApp Web para ver el código.')));
    }
  }

  Future<void> _openWhatsAppLinkedDevices() async {
    final messenger = ScaffoldMessenger.of(context);
    Uri uri = Uri.parse('whatsapp://');
    if (_decodedQrText != null && _decodedQrText!.isNotEmpty) {
      uri = Uri.parse(_decodedQrText!.startsWith('http')
          ? _decodedQrText!
          : 'https://wa.me/settings/linked_devices#$_decodedQrText');
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text('Vinculación en Mismo Teléfono', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _fetchNativeScreenshot),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<WhatsAppWebSessionInfo>(
            stream: whatsAppWebBridgeController.sessionStream,
            initialData: whatsAppWebBridgeController.currentSession,
            builder: (context, snapshot) {
              final qrUrl = snapshot.data?.qrDataUrl;
              final bytes = (qrUrl != null && qrUrl.contains(',')) ? base64Decode(qrUrl.split(',').last) : (_domQrBytes ?? _screenshotBytes);
              if (bytes != null && bytes.isNotEmpty) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade400, width: 2)),
                    child: Image.memory(bytes, width: 180, height: 180, fit: BoxFit.contain),
                  ),
                );
              }
              return Container(height: 120, decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 10), Text(_isCapturing ? 'Escaneando…' : 'Cargando QR…', style: const TextStyle(fontSize: 12))]));
            },
          ),
          if (_decodedQrText != null && _decodedQrText!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: Text('QR: $_decodedQrText', style: const TextStyle(fontSize: 10, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          const SizedBox(height: 10),
          ElevatedButton.icon(icon: const Icon(Icons.copy), label: const Text('Copiar Código de 8 Dígitos'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)), onPressed: _copyPairingCode),
          const SizedBox(height: 6),
          OutlinedButton.icon(icon: const Icon(Icons.center_focus_strong, color: Colors.blue), label: const Text('Escanear QR con Google Lens'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)), onPressed: _openGoogleLens),
          const SizedBox(height: 6),
          OutlinedButton.icon(icon: const Icon(Icons.share), label: const Text('Compartir QR a Galería'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)), onPressed: _shareQrImage),
          const SizedBox(height: 6),
          OutlinedButton.icon(icon: const Icon(Icons.launch), label: const Text('Abrir WhatsApp para Vincular'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)), onPressed: _openWhatsAppLinkedDevices),
        ],
      ),
    );
  }
}
