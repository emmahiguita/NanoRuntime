/// BOT-SKILL-03 — Definición de Skills Modulares Instalables por Bot.
///
/// **QUÉ HACE:**
/// Agrupa conjuntos coherentes de herramientas (tools) bajo una capacidad
/// funcional instalable (ej. LinuxSkill, WhatsAppSkill, CatalogSkill).
///
/// **CÓMO FUNCIONA:**
/// Expone las herramientas disponibles para el planificador del bot, permitiendo
/// que cada agente active únicamente las habilidades necesarias para su rol.
///
/// **POR QUÉ:**
/// Reemplaza prompts gigantescos por contratos de ejecución limpios y modulares,
/// reduciendo el consumo de tokens y evitando alucinaciones.
library;

import 'package:flutter/material.dart';

final class BotSkill {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<String> toolNames;
  final IconData icon;
  final bool requiresPrivilege;

  const BotSkill({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.toolNames,
    this.icon = Icons.extension_rounded,
    this.requiresPrivilege = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'toolNames': toolNames,
        'requiresPrivilege': requiresPrivilege,
      };

  factory BotSkill.fromMap(Map<dynamic, dynamic> map) {
    return BotSkill(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      description: map['description']?.toString() ?? '',
      toolNames: (map['toolNames'] as List? ?? const []).whereType<String>().toList(),
      requiresPrivilege: map['requiresPrivilege'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BotSkill && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
