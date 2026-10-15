// whatsapp_web_rtc_helper.dart
//
// QUÉ HACE:
// Coordina permisos WebRTC nativos (cámara/micrófono) e identidad Desktop Client Hints
// para llamadas reales en WhatsApp Web dentro de Nano.
//
// CÓMO FUNCIONA:
// - Verifica que `PermissionRequest.origin` pertenezca a `https://web.whatsapp.com`.
// - Filtra recursos solicitados para autorizar únicamente `MICROPHONE` y `CAMERA`.
// - Solicita permisos runtime de Android antes de responder a `onPermissionRequest`.
//
// POR QUÉ:
// Cumple la política de seguridad de Android WebView y habilita el motor WebRTC oficial.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WhatsAppWebRtcHelper {
  const WhatsAppWebRtcHelper._();

  static const MethodChannel _browserChannel = MethodChannel(
    'com.nanoai/browser_compatibility',
  );
  static Future<void> initializeForWebView(
    InAppWebViewController controller, {
    String? keepAliveId,
  }) async {
    try {
      await _browserChannel.invokeMethod<bool>('setDesktopIdentity', {
        'viewId': keepAliveId ?? '',
        'enabled': true,
      });
    } catch (_) {}
  }

  static Future<bool> requestWhatsAppCallPermissions({
    bool microphone = true,
    bool camera = true,
  }) async {
    try {
      final granted = await _browserChannel.invokeMethod<bool>(
        'requestMediaPermissions',
        {'camera': camera, 'microphone': microphone},
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<PermissionResponse> handlePermissionRequest(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    final origin = request.origin.toString();
    final rawResources = request.resources
        .map((r) => r.toNativeValue())
        .toList();
    _emitLog(controller, '[NanoWA][WebRTC] permission request: $rawResources');
    _emitLog(controller, '[NanoWA][WebRTC] origin: $origin');

    final isWhatsAppOrigin =
        origin == 'https://web.whatsapp.com' ||
        origin.startsWith('https://web.whatsapp.com/');
    if (!isWhatsAppOrigin) {
      _emitLog(controller, '[NanoWA][WebRTC] microphone denied');
      _emitLog(controller, '[NanoWA][WebRTC] camera denied');
      return PermissionResponse(
        resources: const <PermissionResourceType>[],
        action: PermissionResponseAction.DENY,
      );
    }

    final allowedResources = request.resources.where((resource) {
      return resource == PermissionResourceType.MICROPHONE ||
          resource == PermissionResourceType.CAMERA ||
          resource == PermissionResourceType.CAMERA_AND_MICROPHONE;
    }).toList();

    if (allowedResources.isEmpty) {
      return PermissionResponse(
        resources: const <PermissionResourceType>[],
        action: PermissionResponseAction.DENY,
      );
    }

    final needMic = allowedResources.any(
      (r) =>
          r == PermissionResourceType.MICROPHONE ||
          r == PermissionResourceType.CAMERA_AND_MICROPHONE,
    );
    final needCam = allowedResources.any(
      (r) =>
          r == PermissionResourceType.CAMERA ||
          r == PermissionResourceType.CAMERA_AND_MICROPHONE,
    );
    final bothGranted = await requestWhatsAppCallPermissions(
      microphone: needMic,
      camera: needCam,
    );
    final micGranted = needMic ? bothGranted : false;
    final camGranted = needCam ? bothGranted : false;
    _emitLog(
      controller,
      '[NanoWA][WebRTC] microphone ${micGranted ? "granted" : "denied"}',
    );
    _emitLog(
      controller,
      '[NanoWA][WebRTC] camera ${camGranted ? "granted" : "denied"}',
    );

    final grantedResources = allowedResources.where((resource) {
      if (resource == PermissionResourceType.MICROPHONE) return micGranted;
      if (resource == PermissionResourceType.CAMERA) return camGranted;
      return micGranted && camGranted;
    }).toList();

    return PermissionResponse(
      resources: grantedResources,
      action: grantedResources.isEmpty
          ? PermissionResponseAction.DENY
          : PermissionResponseAction.GRANT,
    );
  }

  /// Verifica el entorno WebRTC en la página cargada y registra diagnósticos.
  static Future<void> verifyWebRtcEnvironment(
    InAppWebViewController controller,
  ) async {
    try {
      final res = await controller.evaluateJavascript(
        source: r'''(() => JSON.stringify({
          secureContext: window.isSecureContext === true,
          peerConnection: typeof RTCPeerConnection === 'function',
          mediaDevices: !!navigator.mediaDevices,
          getUserMedia: typeof navigator.mediaDevices?.getUserMedia === 'function',
          crossOriginIsolated: self.crossOriginIsolated === true,
          sharedArrayBuffer: typeof SharedArrayBuffer === 'function'
        }))()''',
      );
      if (res != null) debugPrint('[NanoWA][WebRTC] diagnostics: $res');
    } catch (_) {}
  }

  static void _emitLog(InAppWebViewController controller, String message) {
    debugPrint(message);
    controller.evaluateJavascript(
      source: 'console.log(${jsonEncode(message)});',
    );
  }
}
