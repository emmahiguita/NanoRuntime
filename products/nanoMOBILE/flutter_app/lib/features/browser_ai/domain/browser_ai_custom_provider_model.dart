// browser_ai_custom_provider_model.dart — Modelo inmutable para proveedores web personalizados.
// QUÉ HACE: Almacena la configuración serializable (ID, nombre, URL) de chats web creados por el usuario.
// CÓMO FUNCIONA: Serializa a Map JSON para guardado en SharedPreferences.
// POR QUÉ: Permite persistencia limpia sin acoplar la capa de UI a disco.
library;

import 'package:flutter/foundation.dart';

@immutable
class BrowserAiCustomProviderModel {
  final String id;
  final String name;
  final String url;

  const BrowserAiCustomProviderModel({
    required this.id,
    required this.name,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
  };

  factory BrowserAiCustomProviderModel.fromJson(Map<String, dynamic> json) {
    return BrowserAiCustomProviderModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Chat IA',
      url: json['url'] as String? ?? '',
    );
  }
}
