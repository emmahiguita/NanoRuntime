/// BOT-SKILLS-CATALOG-01 — Catálogo Oficial de Habilidades para Nano Bot Runtime.
///
/// **QUÉ HACE:**
/// Provee el registro estandarizado de habilidades que cualquier bot puede incorporar,
/// asociando cada skill con las herramientas ejecutables reales del sistema.
///
/// **CÓMO FUNCIONA:**
/// Diccionario inmutable de BotSkill categorizadas con íconos, requerimientos de privilegio
/// y conjuntos de herramientas (tools) validadas por el AgentToolDispatcher.
///
/// **POR QUÉ:**
/// Elimina la necesidad de programar lógica desde cero para cada bot nuevo: basta con
/// seleccionar las skills deseadas para dotar al agente de capacidades operativas inmediatas.
library;

import 'package:flutter/material.dart';
import '../../domain/bot/bot_role.dart';
import '../../domain/bot/bot_skill.dart';

final class BotSkillsCatalog {
  BotSkillsCatalog._();

  static const skillLinux = BotSkill(
    id: 'skill_linux',
    name: 'Linux & Scripts Locales',
    category: 'Sistema y Archivos',
    description: 'Ejecución de scripts Python/Bash, procesamiento de datos y utilidades PTY en el sandbox móvil.',
    icon: Icons.terminal_rounded,
    toolNames: ['linux.exec', 'linux.file.read', 'linux.file.write', 'linux.script.run'],
    requiresPrivilege: false,
  );

  static const skillBrowser = BotSkill(
    id: 'skill_browser',
    name: 'Navegación & Web',
    category: 'Conectividad',
    description: 'Apertura de sitios web, búsqueda factual y extracción automatizada de contenido DOM.',
    icon: Icons.language_rounded,
    toolNames: ['browser.open', 'browser.extract', 'browser.search'],
    requiresPrivilege: false,
  );

  static const skillWhatsApp = BotSkill(
    id: 'skill_whatsapp',
    name: 'Mensajería WhatsApp',
    category: 'Comunicación',
    description: 'Envío de respuestas formateadas, archivos PDF, cotizaciones e inspección de contactos reales.',
    icon: Icons.forum_rounded,
    toolNames: ['whatsapp.send', 'whatsapp.sendMedia', 'whatsapp.contacts'],
    requiresPrivilege: false,
  );

  static const skillAndroidUi = BotSkill(
    id: 'skill_android_ui',
    name: 'Accesibilidad Android',
    category: 'Automatización UI',
    description: 'Interacción directa con la pantalla, pulsaciones, gestos y verificación de estado en apps móviles.',
    icon: Icons.touch_app_rounded,
    toolNames: ['android.tap', 'android.scroll', 'android.type', 'android.screenshot'],
    requiresPrivilege: true,
  );

  static const skillCatalog = BotSkill(
    id: 'skill_catalog',
    name: 'Catálogo & Inventario',
    category: 'Comercio',
    description: 'Consulta factual de productos, listas de precios, descuentos y verificación real de existencias.',
    icon: Icons.inventory_2_rounded,
    toolNames: ['catalog.search', 'catalog.getPrice', 'inventory.check'],
    requiresPrivilege: false,
  );

  static const skillPersonalMemory = BotSkill(
    id: 'skill_memory',
    name: 'Memoria & Estilo Personal',
    category: 'Inteligencia',
    description: 'Recuperación de ejemplos de respuesta, hechos episódicos y adaptación de registro comunicativo.',
    icon: Icons.psychology_rounded,
    toolNames: ['memory.get', 'memory.save', 'contact.style'],
    requiresPrivilege: false,
  );

  static const skillCalendar = BotSkill(
    id: 'skill_calendar',
    name: 'Calendario & Citas',
    category: 'Productividad',
    description: 'Consulta de disponibilidad horaria, agendamiento de citas y recordatorios automáticos.',
    icon: Icons.event_available_rounded,
    toolNames: ['calendar.available', 'calendar.book'],
    requiresPrivilege: false,
  );

  static const skillBrowserAi = BotSkill(
    id: 'skill_browser_ai',
    name: 'IA Web Externa (Gateway)',
    category: 'Inteligencia',
    description: 'Razonamiento profundo con ChatGPT, Gemini, Claude y DeepSeek en el navegador.',
    icon: Icons.auto_awesome_rounded,
    toolNames: ['browser.ai.ask', 'browser.ai.providers'],
    requiresPrivilege: false,
  );

  static const List<BotSkill> allSkills = [
    skillWhatsApp,
    skillPersonalMemory,
    skillBrowserAi,
    skillLinux,
    skillBrowser,
    skillCatalog,
    skillCalendar,
    skillAndroidUi,
  ];

  static BotSkill? getSkill(String id) {
    for (final s in allSkills) {
      if (s.id == id) return s;
    }
    return null;
  }

  static List<String> defaultSkillsForRole(BotRole role) {
    switch (role) {
      case BotRole.personal:
        return [skillWhatsApp.id, skillPersonalMemory.id, skillLinux.id, skillBrowser.id];
      case BotRole.sales:
        return [skillWhatsApp.id, skillCatalog.id, skillCalendar.id];
      case BotRole.support:
        return [skillWhatsApp.id, skillBrowser.id, skillAndroidUi.id];
      case BotRole.assistant:
        return [skillWhatsApp.id, skillLinux.id, skillCalendar.id, skillBrowser.id];
      case BotRole.custom:
        return [skillWhatsApp.id];
    }
  }
}
