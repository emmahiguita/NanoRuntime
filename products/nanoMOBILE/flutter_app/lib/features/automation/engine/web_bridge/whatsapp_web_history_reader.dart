/// Captura y guarda por cuenta; no convierte previews en mensajes.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'whatsapp_web_bridge_controller.dart';
import 'whatsapp_web_history_message.dart';
import 'whatsapp_web_history_scripts.dart';
import 'whatsapp_web_history_selection.dart';
import 'whatsapp_web_history_store.dart';
import 'whatsapp_web_observer_access.dart';
import 'whatsapp_web_operation_lock.dart';
import 'whatsapp_web_account_guard.dart';

final class WhatsAppWebHistoryReader {
  final store = WhatsAppWebHistoryStore();
  final String? _expectedAccount;
  WhatsAppWebHistoryReader({String? expectedAccount})
    : _expectedAccount = expectedAccount,
      account = expectedAccount == null || expectedAccount.isEmpty
          ? null
          : sha256.convert(utf8.encode(expectedAccount)).toString();

  /// La cuenta viene del alias publicado por el feed, nunca de una preferencia
  /// global que podría pertenecer a otro número vinculado.
  factory WhatsAppWebHistoryReader.forAlias(String alias) {
    final parts = alias.startsWith('waweb:')
        ? alias.substring(6).split('/')
        : const <String>[];
    return WhatsAppWebHistoryReader(
      expectedAccount: parts.length == 2
          ? Uri.decodeComponent(parts.first)
          : '',
    );
  }
  String? account;
  String? _chat;
  bool _cancelled = false;
  String? _savedSignature;
  List<WhatsAppWebHistoryMessage> latestRows = const [];
  void dispose() => _cancelled = true;

  /// Solo consulta el archivo de la cuenta seleccionada y comprobada.
  Future<String?> knownAccount() async => account;

  Future<int> capture(
    String title,
    String alias, {
    bool earlier = false,
    bool Function()? interrupted,
  }) => WhatsAppWebOperationLock.run(
    () => _capture(title, alias, earlier: earlier, interrupted: interrupted),
  );

  /// El lease abarca selección, paginación y lectura: un envío no cambia el chat.
  Future<int> _capture(
    String title,
    String alias, {
    bool earlier = false,
    bool Function()? interrupted,
  }) async {
    latestRows = const [];
    if (_expectedAccount == '') {
      throw StateError('El historial requiere identificar la cuenta Web');
    }
    final ctrl = whatsAppWebBridgeController.retainedController;
    if (ctrl == null) throw StateError('La sesión Web todavía está arrancando');
    // La UI puede ceder el WebView a la ruta visible mientras esperamos React.
    bool cancelled() => _cancelled || interrupted?.call() == true;
    // No selecciona siquiera un nombre en otra cuenta vinculada.
    if (_expectedAccount != null) {
      await WhatsAppWebAccountGuard.check(ctrl, _expectedAccount);
    }
    if (cancelled()) return 0;
    var data = await WhatsAppWebHistorySelection.read(ctrl, title, cancelled);
    if (cancelled()) return 0;
    if (earlier) {
      final moved = await WhatsAppWebObserverAccess.evaluate(
        ctrl,
        WhatsAppWebHistoryScripts.earlier,
      );
      if (!moved) {
        throw StateError('WhatsApp no expone más mensajes en esta página');
      }
      // El scroll solicita una página asíncrona: no captura inmediatamente la anterior.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      data = await WhatsAppWebHistorySelection.read(ctrl, title, cancelled);
      if (cancelled()) return 0;
    }
    final accountId = (data['accountId'] ?? '').toString();
    if (accountId.isEmpty) {
      throw StateError('No se pudo identificar la cuenta Web');
    }
    if (_expectedAccount != null && accountId != _expectedAccount) {
      throw StateError(
        'La cuenta vinculada no coincide con el chat seleccionado',
      );
    }
    final nextAccount = sha256.convert(utf8.encode(accountId)).toString();
    if (account != nextAccount) {
      _chat = null;
    }
    account = nextAccount;
    final rawRows = data['rows'] as List? ?? const [];
    final locale = (data['locale'] ?? '').toString();
    final rows = rawRows
        .map(
          (r) => WhatsAppWebHistoryMessage.fromDom(
            Map<String, dynamic>.from(r),
            locale,
          ),
        )
        .whereType<WhatsAppWebHistoryMessage>()
        .toList();
    if (rows.isNotEmpty) {
      final chat = (data['chatId'] ?? '').toString();
      if (chat.isEmpty) throw StateError('No se pudo identificar el hilo Web');
      if (_chat != null && _chat != chat) {
        throw StateError('La identidad del chat cambió');
      }
      _chat = chat;
      final signature = sha256
          .convert(
            utf8.encode(
              jsonEncode([
                account,
                chat,
                alias,
                rows.map((r) => r.toStored()).toList(),
              ]),
            ),
          )
          .toString();
      // Un hilo sin cambios no debe hacer escrituras SQLite cada dos segundos.
      if (signature != _savedSignature) {
        await store.append(account!, chat, alias, rows);
        _savedSignature = signature;
      }
    }
    // Un adjunto no impide guardar primero los mensajes legibles.
    latestRows = List.unmodifiable(rows);
    if (rows.length != rawRows.length || (data['skipped'] as num? ?? 0) > 0) {
      throw StateError(
        'Hay mensajes con formato o adjuntos aún no compatibles',
      );
    }
    return rows.length;
  }
}
