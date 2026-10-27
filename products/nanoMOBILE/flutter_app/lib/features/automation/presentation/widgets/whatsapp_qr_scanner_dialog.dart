/// WA-QR-SCANNER-01 — Ventana flotante de escaneo QR e inspección directa en Nano.
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
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/whatsapp_media_payload.dart';
import '../../engine/web_bridge/whatsapp_web_bridge_controller.dart';

part 'whatsapp_qr_scanner_dialog_view.part.dart';

class WhatsAppQrScannerDialog extends StatefulWidget {
  const WhatsAppQrScannerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showNanoGlassWindow<void>(
      context: context,
      builder: (ctx) => const WhatsAppQrScannerDialog(),
    );
  }

  @override
  State<WhatsAppQrScannerDialog> createState() =>
      _WhatsAppQrScannerDialogState();
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
      try {
        domBytes = base64Decode(session.qrDataUrl!.split(',').last);
      } catch (_) {}
    }
    final screenBytes = await whatsAppWebBridgeController.captureScreen();
    final bytesToScan = domBytes ?? screenBytes;
    String? decoded = session.qrDataRef;
    if ((decoded == null || decoded.isEmpty) &&
        bytesToScan != null &&
        bytesToScan.isNotEmpty) {
      try {
        final res = await const MethodChannel(
          'com.nanoai/agent',
        ).invokeMethod('scanQr', {'png': bytesToScan});
        if (res is List && res.isNotEmpty) {
          decoded =
              (Map<String, dynamic>.from(res.first as Map))['rawValue']
                  as String?;
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
      try {
        return base64Decode(session.qrDataUrl!.split(',').last);
      } catch (_) {}
    }
    return _screenshotBytes ??
        await whatsAppWebBridgeController.captureScreen();
  }

  Future<void> _openGoogleLens() async {
    final bytes = await _getBestQrBytes();
    if (bytes == null || bytes.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nano_whatsapp_qr.png');
      await file.writeAsBytes(bytes);
      final ok = await const MethodChannel(
        'com.nanoai/agent',
      ).invokeMethod('openGoogleLens', {'filePath': file.path});
      if (ok != true) await _shareQrImage();
    } catch (_) {
      await _shareQrImage();
    }
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
      messenger.showSnackBar(
        SnackBar(content: Text('¡Código $code copiado! Pégalo en WhatsApp.')),
      );
    } else {
      await whatsAppWebBridgeController.switchToPhoneLinking();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Ingresa tu teléfono en WhatsApp Web para ver el código.',
          ),
        ),
      );
    }
  }

  Future<void> _openWhatsAppLinkedDevices() async {
    final messenger = ScaffoldMessenger.of(context);
    Uri uri = Uri.parse('whatsapp://');
    if (_decodedQrText != null && _decodedQrText!.isNotEmpty) {
      uri = Uri.parse(
        _decodedQrText!.startsWith('http')
            ? _decodedQrText!
            : 'https://wa.me/settings/linked_devices#$_decodedQrText',
      );
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _buildQrScannerContent(context);
}
