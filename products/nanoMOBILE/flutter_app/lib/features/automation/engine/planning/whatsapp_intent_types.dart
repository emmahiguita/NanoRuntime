// whatsapp_intent_types.dart
// ¿Qué hace? Tipos de datos inmutables para representar intenciones de WhatsApp.
// ¿Por qué? SRP — separar los tipos del parser evita archivos sobrecargados (>200 líneas).
// ¿Cómo? Define WhatsAppAction y WhatsAppIntent.
// SOLID: OCP — abierto a nuevos tipos de acciones sin acoplar la lógica de parsing.

import 'package:flutter/foundation.dart';

/// Tipos de acción reconocidos para WhatsApp.
enum WhatsAppAction { findContact, openChat, sendMessage, shareFile }

/// Representación tipada de una intención de WhatsApp.
@immutable
class WhatsAppIntent {
  final WhatsAppAction action;
  final String contact; // Nombre o número del destinatario
  final String? message; // Texto del mensaje (si aplica)
  final String? filePath; // Ruta del archivo a compartir (si aplica)

  const WhatsAppIntent({
    required this.action,
    required this.contact,
    this.message,
    this.filePath,
  });
}
