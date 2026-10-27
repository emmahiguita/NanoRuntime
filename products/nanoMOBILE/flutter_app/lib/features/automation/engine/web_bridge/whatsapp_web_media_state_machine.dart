// whatsapp_web_media_state_machine.dart
//
// QUÉ HACE:
// Máquina de estados determinista y fail-closed para el envío multimedia en WhatsApp Web.
//
// CÓMO FUNCIONA:
// - Recorre secuencialmente: [validatingPayload] -> [preparingContext] ->
//   [stagingBlob] -> [awaitingPreviewModal] -> [committingSend] -> estado terminal.
// - Valida existencia física del archivo, límite de 12 MB (evita OOM en el puente JS),
//   MIME permitido, formato internacional E.164 del destinatario y cuenta vinculada.
// - Adquiere [WhatsAppWebOperationLock] durante toda la transición y nunca reintenta
//   si el commit entra en estado incierto (`outcomeUnknown`).
//
// POR QUÉ:
// Completa el Punto 5 con garantías reales de seguridad: evita envíos al destinatario
// equivocado, saturación de memoria o confirmaciones falsas sin preview verificado.

library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/whatsapp_media_payload.dart';
import '../orchestration/commit_guard.dart';
import 'whatsapp_web_media_models.dart';
import 'whatsapp_web_media_scripts.dart';
import 'whatsapp_web_observer_access.dart';
import 'whatsapp_web_operation_lock.dart';

export 'whatsapp_web_media_models.dart';

final class WhatsAppWebMediaStateMachine {
  /// Límite máximo seguro para transferencia Base64 hacia el WebView (12 MB).
  static const int maxFileBytes = 12 * 1024 * 1024;

  static const Set<String> allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'video/mp4',
    'application/pdf',
  };

  const WhatsAppWebMediaStateMachine();

  /// Ejecuta la máquina de estados sobre el [InAppWebViewController] real.
  Future<WhatsAppWebMediaMachineResult> dispatch({
    required InAppWebViewController? controller,
    required bool connected,
    required WhatsAppMediaPayload payload,
    required String recipientPhone,
    required String expectedAccount,
  }) async {
    if (controller == null || !connected) {
      return WhatsAppWebMediaMachineResult.abort(
        const [WhatsAppWebMediaState.idle],
        'Sesión de WhatsApp Web desconectada o controlador nulo',
      );
    }
    return executeWithRunner(
      payload: payload,
      recipientPhone: recipientPhone,
      expectedAccount: expectedAccount,
      runner: (phase, script) async {
        final raw = phase == 'prepare'
            ? await WhatsAppWebObserverAccess.read(controller, script)
            : await WhatsAppWebObserverAccess.executeOnce(controller, script);
        final decoded = raw is String ? jsonDecode(raw) : raw;
        return decoded is Map
            ? decoded.cast<String, dynamic>()
            : <String, dynamic>{};
      },
    );
  }

  /// Motor puro de transiciones verificables con soporte de inyección de runner.
  Future<WhatsAppWebMediaMachineResult> executeWithRunner({
    required WhatsAppMediaPayload payload,
    required String recipientPhone,
    required String expectedAccount,
    required WebScriptRunner runner,
  }) async {
    final visited = <WhatsAppWebMediaState>[
      WhatsAppWebMediaState.idle,
      WhatsAppWebMediaState.validatingPayload,
    ];
    final phone = recipientPhone.trim().replaceAll(RegExp(r'[\s()+-]'), '');
    final filePath = payload.filePath?.trim() ?? '';
    if (expectedAccount.trim().isEmpty ||
        filePath.isEmpty ||
        !RegExp(r'^[1-9]\d{7,14}$').hasMatch(phone) ||
        !allowedMimeTypes.contains(payload.mimeType.toLowerCase())) {
      return WhatsAppWebMediaMachineResult.abort(
        visited,
        'Cuenta, teléfono internacional o MIME inválidos',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return WhatsAppWebMediaMachineResult.abort(
        visited,
        'El archivo multimedia no existe en disco',
      );
    }

    final length = await file.length();
    if (length <= 0 || length > maxFileBytes) {
      return WhatsAppWebMediaMachineResult.abort(
        visited,
        'Tamaño fuera del rango seguro (1B .. 12MB)',
      );
    }

    final base64Data = base64Encode(await file.readAsBytes());

    return WhatsAppWebOperationLock.run(() async {
      visited.add(WhatsAppWebMediaState.preparingContext);
      final prepared = await runner(
        'prepare',
        WhatsAppWebMediaScripts.prepare(
          phone: phone,
          expectedAccount: expectedAccount,
        ),
      );
      if (prepared['status'] != 'ready') {
        return WhatsAppWebMediaMachineResult.fromWebResponse(visited, prepared);
      }

      final account = '${prepared['account'] ?? ''}';
      final chat = '${prepared['chat'] ?? ''}';
      final title = '${prepared['title'] ?? ''}';

      visited.add(WhatsAppWebMediaState.stagingBlob);
      final staged = await runner(
        'stage',
        WhatsAppWebMediaScripts.stageBlob(
          phone: phone,
          account: account,
          chat: chat,
          title: title,
          base64Data: base64Data,
          fileName: payload.fileName,
          mimeType: payload.mimeType,
        ),
      );
      if (staged['status'] != 'mediaStaged') {
        return WhatsAppWebMediaMachineResult.fromWebResponse(visited, staged);
      }

      visited.add(WhatsAppWebMediaState.awaitingPreviewModal);
      for (var attempt = 0; attempt < 6; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 140));
        }
        visited.add(WhatsAppWebMediaState.committingSend);
        final committed = await runner(
          'commit',
          WhatsAppWebMediaScripts.commitPreview(
            phone: phone,
            account: account,
            chat: chat,
            title: title,
            caption: payload.caption ?? '',
          ),
        );
        if (committed['status'] != 'waiting') {
          return WhatsAppWebMediaMachineResult.fromWebResponse(
            visited,
            committed,
          );
        }
      }

      return WhatsAppWebMediaMachineResult.abort(
        visited,
        'El modal de previsualización multimedia no confirmó el botón de envío',
        status: SendEvidenceStatus.incompleteEvidence,
      );
    });
  }
}
