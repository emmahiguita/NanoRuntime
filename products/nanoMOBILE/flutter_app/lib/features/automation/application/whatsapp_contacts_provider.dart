import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/whatsapp_contact.dart';
import '../presentation/messaging_center/messaging_center_providers.dart'
    show messagingSearchQueryProvider;

/// Servicio de comunicación con el canal nativo `com.nanoai/contacts`.
///
/// QUÉ HACE:
/// - Consulta permisos y contactos con integración de WhatsApp vía ContactsProvider.
/// - Ofrece selección de contacto único (ACTION_PICK) sin requerir permiso global.
/// - Comprueba la presencia de WhatsApp Personal y WhatsApp Business instalados.
///
/// CÓMO SE CONECTA:
/// - Se comunica mediante MethodChannel con ContactsChannelHandler en Android.
///
/// POR QUÉ:
/// - Centraliza la capa de infraestructura de contactos (< 160 líneas).
class WhatsAppContactsService {
  static const _channel = MethodChannel('com.nanoai/contacts');

  /// Verifica si el permiso READ_CONTACTS está concedido.
  Future<bool> hasPermission() async {
    final res = await _channel.invokeMethod<bool>('hasContactsPermission');
    return res == true;
  }

  /// Solicita el permiso READ_CONTACTS al usuario.
  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'requestContactsPermission',
      );
      return res == true;
    } on PlatformException {
      return false;
    }
  }

  /// Consulta la lista de contactos de WhatsApp sincronizados en el dispositivo.
  Future<List<WhatsAppContact>> getContacts() async {
    final res = await _channel.invokeListMethod<dynamic>('getWhatsAppContacts');
    if (res == null) return const [];
    return res
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => WhatsAppContact.fromMap(m))
        .toList();
  }

  /// Abre el selector nativo de contactos de Android (ACTION_PICK) sin permiso global.
  Future<WhatsAppContact?> pickSingleContact() async {
    try {
      final res = await _channel.invokeMapMethod<dynamic, dynamic>('pickSingleContact');
      if (res == null) return null;
      return WhatsAppContact.fromMap(res);
    } on PlatformException {
      return null;
    }
  }

  /// Detecta si WhatsApp Personal y Business están instalados en el dispositivo.
  Future<Map<String, bool>> getInstalledWhatsAppPackages() async {
    try {
      final res = await _channel.invokeMapMethod<dynamic, dynamic>('getInstalledWhatsAppPackages');
      if (res == null) return {'personal': false, 'business': false};
      return res.map((k, v) => MapEntry(k.toString(), v == true));
    } on PlatformException {
      return {'personal': false, 'business': false};
    }
  }

  /// Abre la ficha nativa oficial de Android (QuickContact) con las acciones del contacto.
  Future<bool> showQuickContact(String contactId) async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'showQuickContact',
        {'contactId': contactId},
      );
      return res == true;
    } on PlatformException {
      return false;
    }
  }
}

/// Provider singleton del servicio de contactos de WhatsApp.
final whatsappContactsServiceProvider = Provider<WhatsAppContactsService>(
  (ref) => WhatsAppContactsService(),
);

/// Estado del permiso de contactos.
final contactsPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(whatsappContactsServiceProvider);
  return service.hasPermission();
});

/// Paquetes instalados de WhatsApp (personal y business).
final installedWhatsAppPackagesProvider = FutureProvider<Map<String, bool>>((ref) async {
  final service = ref.watch(whatsappContactsServiceProvider);
  return service.getInstalledWhatsAppPackages();
});

/// Lista completa de contactos de WhatsApp en el dispositivo.
final allWhatsAppContactsProvider = FutureProvider<List<WhatsAppContact>>((
  ref,
) async {
  final service = ref.watch(whatsappContactsServiceProvider);
  final hasPerm = await ref.watch(contactsPermissionProvider.future);
  if (!hasPerm) return const [];
  return service.getContacts();
});

/// Contactos de WhatsApp filtrados por la búsqueda activa en el Centro de Mensajería.
final filteredWhatsAppContactsProvider = Provider<List<WhatsAppContact>>((ref) {
  final contactsAsync = ref.watch(allWhatsAppContactsProvider);
  final contacts = contactsAsync.value ?? const [];
  final query = ref.watch(messagingSearchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) return contacts;

  return contacts.where((c) {
    final matchName = c.name.toLowerCase().contains(query);
    final matchNumber = c.number.contains(query);
    return matchName || matchNumber;
  }).toList();
});

/// Notifier para almacenar y recuperar los destinatarios recientes de Nano (< 8 registros).
class RecentShareContactsNotifier extends StateNotifier<List<WhatsAppContact>> {
  static const _storageKey = 'nano_recent_share_recipients_v1';

  RecentShareContactsNotifier() : super(const []) {
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey);
      if (rawList == null || rawList.isEmpty) return;
      final parsed = rawList
          .map((item) {
            try {
              return WhatsAppContact.fromMap(jsonDecode(item) as Map<dynamic, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<WhatsAppContact>()
          .toList();
      state = parsed;
    } catch (_) {}
  }

  Future<void> rememberContact(WhatsAppContact contact) async {
    final updated = [
      contact,
      ...state.where((c) => c.number != contact.number && c.jid != contact.jid),
    ].take(8).toList();
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = updated.map((c) => jsonEncode(c.toMap())).toList();
      await prefs.setStringList(_storageKey, rawList);
    } catch (_) {}
  }
}

final recentShareContactsProvider =
    StateNotifierProvider<RecentShareContactsNotifier, List<WhatsAppContact>>(
  (ref) => RecentShareContactsNotifier(),
);
