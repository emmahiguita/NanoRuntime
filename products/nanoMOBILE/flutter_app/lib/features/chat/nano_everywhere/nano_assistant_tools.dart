import 'package:flutter/material.dart';

/// Metadatos visuales; las claves conservan los contratos del motor existente.
/// Seleccionar cambia contexto y no ejecuta ni consulta proveedores.
class NanoAssistantTool {
  const NanoAssistantTool(this.key, this.label, this.description, this.icon);
  final String key, label, description;
  final IconData icon;
  static const all = [
    NanoAssistantTool(
      'Chat',
      'Conversar',
      'Consulta al asistente con el modelo o la conexión disponible.',
      Icons.chat_bubble_outline_rounded,
    ),
    NanoAssistantTool(
      'Pantalla',
      'Leer pantalla',
      'Lee texto accesible de la app activa. No analiza imágenes.',
      Icons.article_outlined,
    ),
    NanoAssistantTool(
      'Auto',
      'Controlar apps',
      'Indica una acción concreta para el motor de automatización.',
      Icons.touch_app_outlined,
    ),
    NanoAssistantTool(
      'WhatsApp',
      'WhatsApp',
      'Busca un contacto, abre un chat o indica qué enviar.',
      Icons.chat_outlined,
    ),
    NanoAssistantTool(
      'Media',
      'Descargar enlace',
      'Pega un enlace para buscar archivos descargables.',
      Icons.download_outlined,
    ),
  ];

  /// Recupera una opción válida sin cambiar las claves guardadas de la sesión.
  static NanoAssistantTool fromKey(String key) =>
      all.firstWhere((tool) => tool.key == key, orElse: () => all.first);
}
