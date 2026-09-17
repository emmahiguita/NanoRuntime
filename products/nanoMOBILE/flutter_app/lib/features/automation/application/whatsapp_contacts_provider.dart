import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/whatsapp_contact.dart';
import '../presentation/messaging_center/messaging_center_providers.dart'
    show messagingSearchQueryProvider;

/// Servicio de comunicación con el canal nativo `com.nanoai/contacts`.
class WhatsAppContactsService {
  static const _channel = MethodChannel('com.nanoai/contacts');

  /// Verifica si el permiso READ_CONTACTS está concedido.
  Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasContactsPermission');
      return res == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Solicita el permiso READ_CONTACTS al usuario.
  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestContactsPermission');
      return res == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Consulta la lista de contactos de WhatsApp sincronizados en el dispositivo.
  Future<List<WhatsAppContact>> getContacts() async {
    try {
      final res = await _channel.invokeListMethod<dynamic>('getWhatsAppContacts');
      if (res == null) return const [];
      return res
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => WhatsAppContact.fromMap(m))
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}

/// Provider singleton del servicio de contactos de WhatsApp.
final whatsappContactsServiceProvider =
    Provider<WhatsAppContactsService>((ref) => WhatsAppContactsService());

/// Estado del permiso de contactos.
final contactsPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(whatsappContactsServiceProvider);
  return service.hasPermission();
});

/// Lista completa de contactos de WhatsApp en el dispositivo.
final allWhatsAppContactsProvider =
    FutureProvider<List<WhatsAppContact>>((ref) async {
  final service = ref.watch(whatsappContactsServiceProvider);
  final hasPerm = await service.hasPermission();
  if (!hasPerm) return const [];
  return service.getContacts();
});

/// Contactos de WhatsApp filtrados por la búsqueda activa en el Centro de Mensajería.
final filteredWhatsAppContactsProvider =
    Provider<List<WhatsAppContact>>((ref) {
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
