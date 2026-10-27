/// Transporte Web con destino comprobado; no convierte un clic en entrega.
/// Los adjuntos se rechazan hasta disponer de un commit verificable del preview.
library;

import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/whatsapp_media_payload.dart';
import '../orchestration/commit_guard.dart';
import 'whatsapp_web_dispatch_scripts.dart';
import 'whatsapp_web_media_state_machine.dart';
import 'whatsapp_web_observer_access.dart';
import 'whatsapp_web_operation_lock.dart';

abstract final class WhatsAppWebMessageTransport {
  static const _mediaMachine = WhatsAppWebMediaStateMachine();

  /// Despacha adjuntos a través de la máquina de estados multimedia verificable.
  static Future<bool> sendMedia(
    InAppWebViewController? controller,
    bool connected,
    WhatsAppMediaPayload payload, {
    required String recipientPhone,
    String expectedAccount = '',
  }) async {
    final result = await _mediaMachine.dispatch(
      controller: controller,
      connected: connected,
      payload: payload,
      recipientPhone: recipientPhone,
      expectedAccount: expectedAccount,
    );
    return result.isDispatched;
  }

  /// Conserva la API bool: true significa despacho, nunca entrega confirmada.
  static Future<bool> sendText(
    InAppWebViewController? controller,
    bool connected,
    String text, {
    required String recipientPhone,
    required String expectedAccount,
  }) async {
    final evidence = await dispatchText(
      controller,
      connected,
      text,
      recipientPhone: recipientPhone,
      expectedAccount: expectedAccount,
    );
    return evidence.status == SendEvidenceStatus.dispatchedUnverified;
  }

  /// Bloquea lectores concurrentes y revalida cuenta/chat justo antes del clic.
  static Future<SendEvidence> dispatchText(
    InAppWebViewController? controller,
    bool connected,
    String text, {
    required String recipientPhone,
    required String expectedAccount,
  }) async {
    final phone = recipientPhone.trim().replaceAll(RegExp(r'[\s()+-]'), '');
    final draft = text.trim();
    if (controller == null ||
        !connected ||
        expectedAccount.isEmpty ||
        !RegExp(r'^[1-9]\d{7,14}$').hasMatch(phone) ||
        draft.isEmpty ||
        draft.length > 4096) {
      return const SendEvidence(
        SendEvidenceStatus.notExecuted,
        'Sesión, número internacional o texto inválidos',
      );
    }
    var expired = false;
    try {
      // El lock sigue ocupado hasta acabar la operación subyacente. El timeout
      // no permite otro envío mientras la respuesta del WebView sea incierta.
      return await WhatsAppWebOperationLock.run(() async {
        final prepared = _decode(
          await WhatsAppWebObserverAccess.read(
            controller,
            WhatsAppWebDispatchScripts.prepare(phone, expectedAccount),
          ),
        );
        if (expired) {
          return const SendEvidence(
            SendEvidenceStatus.notExecuted,
            'Solicitud expirada antes de escribir',
          );
        }
        if (prepared['status'] != 'ready') return _evidence(prepared);
        try {
          String script(String body) => WhatsAppWebDispatchScripts.operation(
            phone: phone,
            text: draft,
            account: prepared['account'] as String,
            chat: prepared['chat'] as String,
            title: prepared['title'] as String,
            body: body,
          );
          final staged = _decode(
            await WhatsAppWebObserverAccess.executeOnce(
              controller,
              script(WhatsAppWebDispatchScripts.stageBody),
            ),
          );
          if (staged['status'] != 'draftPrepared') return _evidence(staged);
          // Esperas limitadas a renderizado. Solo "waiting" permite otra
          // consulta, porque el script confirma que no pulsó enviar.
          for (var attempt = 0; attempt < 5 && !expired; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 120));
            if (expired) break;
            final committed = _decode(
              await WhatsAppWebObserverAccess.executeOnce(
                controller,
                script(WhatsAppWebDispatchScripts.commitBody),
              ),
            );
            if (committed['status'] != 'waiting') return _evidence(committed);
          }
          return const SendEvidence(
            SendEvidenceStatus.incompleteEvidence,
            'Borrador sin commit confirmado; no se reintenta el envío',
          );
        } catch (_) {
          return const SendEvidence(
            SendEvidenceStatus.outcomeUnknown,
            'Sin confirmación del commit Web; no reintentar',
          );
        }
      }).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          expired = true;
          return const SendEvidence(
            SendEvidenceStatus.outcomeUnknown,
            'WebView pendiente; no reintentar el envío',
          );
        },
      );
    } catch (_) {
      return const SendEvidence(
        SendEvidenceStatus.notExecuted,
        'WebView ocupado o no disponible antes de escribir',
      );
    }
  }

  /// Una respuesta malformada no se interpreta como éxito.
  static Map<dynamic, dynamic> _decode(Object? raw) {
    final value = raw is String ? jsonDecode(raw) : raw;
    return value is Map ? value : const {};
  }

  static SendEvidence _evidence(Map<dynamic, dynamic> data) => SendEvidence(
    switch (data['status']) {
      'notExecuted' => SendEvidenceStatus.notExecuted,
      'dispatchedUnverified' => SendEvidenceStatus.dispatchedUnverified,
      'contextChanged' => SendEvidenceStatus.contextChanged,
      'incompleteEvidence' => SendEvidenceStatus.incompleteEvidence,
      _ => SendEvidenceStatus.outcomeUnknown,
    },
    data['reason'] is String
        ? data['reason'] as String
        : 'Respuesta Web no verificable; no reintentar',
  );
}
