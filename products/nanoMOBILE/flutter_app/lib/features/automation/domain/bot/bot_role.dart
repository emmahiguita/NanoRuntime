/// BOT-ROLE-01 — Roles canónicos y propósitos de agentes en Nano Bot Runtime.
///
/// **QUÉ HACE:**
/// Define la clasificación funcional de cada bot configurado en el sistema,
/// estableciendo su comportamiento base, restricciones de gobernanza y visualización.
///
/// **CÓMO FUNCIONA:**
/// Enumeración con metadatos descriptivos en español, identificador serializable
/// para persistencia en SQLite y asignación de icono representativo.
///
/// **POR QUÉ:**
/// Permite que Nano distinga entre un asistente personal con acceso al sistema,
/// un bot de ventas enfocado en conversión comercial o un agente de soporte técnico.
library;

import 'package:flutter/material.dart';

enum BotRole {
  personal('personal', 'Asistente Personal', Icons.person_rounded),
  sales('sales', 'Ventas y Negocio', Icons.storefront_rounded),
  support('support', 'Soporte y Atención', Icons.support_agent_rounded),
  assistant('assistant', 'Operaciones y Tareas', Icons.smart_toy_rounded),
  custom('custom', 'Personalizado', Icons.extension_rounded);

  final String key;
  final String label;
  final IconData icon;

  const BotRole(this.key, this.label, this.icon);

  static BotRole fromKey(String? key) {
    if (key == null || key.isEmpty) return BotRole.personal;
    return BotRole.values.firstWhere(
      (r) => r.key == key,
      orElse: () => BotRole.custom,
    );
  }

  String get defaultGoal {
    switch (this) {
      case BotRole.personal:
        return 'Representar al usuario con su estilo natural, gestionar recordatorios y ejecutar tareas locales.';
      case BotRole.sales:
        return 'Atender consultas comerciales, verificar disponibilidad, cotizar y guiar hacia la compra sin inventar datos.';
      case BotRole.support:
        return 'Diagnosticar incidentes, consultar documentación técnica y resolver inquietudes con claridad factual.';
      case BotRole.assistant:
        return 'Automatizar flujos de trabajo, procesar archivos y coordinar herramientas del dispositivo.';
      case BotRole.custom:
        return 'Objetivo definido por el usuario según sus necesidades específicas.';
    }
  }
}
