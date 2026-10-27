/// ToolRegistry + PolicyEngine — gobernanza del tool-calling (§12 del plan
/// de automatización: "Tool Registry" + "Controles obligatorios").
///
/// Toda herramienta que el agente puede ejecutar contra el dispositivo vive
/// en un registro con riesgo, timeout y requisito de confirmación. El motor
/// de política decide allow / needsConfirmation / denied ANTES de ejecutar:
///
///   - Herramienta desconocida → denied (el modelo ve el error y se corrige;
///     jamás se ejecuta algo fuera del registro).
///   - Presupuesto de pasos por turno agotado → denied (anti-bucle: un GGUF
///     pequeño que insiste en llamar tools no puede iterar para siempre).
///   - externalWrite sin confirmación → needsConfirmation (el humano decide).
///
/// Origen de la acción: los comandos `@` los escribe el usuario → autoría
/// humana = confirmación implícita. El tool-calling del LLM es agencia
/// autónoma → las escrituras externas SIEMPRE piden confirmación.
///
/// Puro: sin MethodChannel ni UI — testeable con fixtures.
library;

import '../governance/semantic_policy.dart';

/// Riesgo de una herramienta. Orden creciente de impacto.

part 'tool_definition.dart';
part 'tool_policy_engine.dart';
part 'tool_definitions_0.dart';
part 'tool_definitions_1.dart';
part 'tool_definitions_2.dart';
part 'tool_definitions_3.dart';
part 'tool_definitions_4.dart';
part 'tool_definitions_5.dart';

enum ToolRisk { none, read, device, externalWrite }

class ToolRegistry {
  ToolRegistry(
    Map<String, ToolDefinition> byName, {
    Map<String, String> aliases = const {},
  }) : _byName = byName,
       _aliases = aliases;

  final Map<String, ToolDefinition> _byName;
  final Map<String, String> _aliases;

  /// Registro por defecto del agente UI (canal com.nanoai/agent).
  static final ToolRegistry builtin = ToolRegistry(
    {for (final d in _builtinDefs) d.name: d},
    aliases: {
      'pantalla': 'screen',
      'resolver': 'resolve',
      'tocar': 'tap',
      'escribir': 'write',
      'notificaciones': 'notifications',
      'responder_notificacion': 'reply_notification',
      'atras': 'back',
      'atrás': 'back',
      'inicio': 'home',
      'recientes': 'recents',
      'sombra': 'open_notifications',
      'ajustes_rapidos': 'open_quick_settings',
      'linux.readfile': 'linux.readFile',
      'linux.writefile': 'linux.writeFile',
      'estado_dispositivo': 'device_state',
      'abrir': 'launch_app',
      'abrir_app': 'launch_app',
      'url': 'open_url',
      'web': 'fetch_web',
      'fetch': 'fetch_web',
      'buscar': 'search_knowledge',
      'search': 'search_knowledge',
      'search_web': 'search_knowledge',
      'google': 'search_knowledge',
      'conocimiento': 'search_knowledge',
      'gemini': 'browser_ai_query',
      'chatgpt': 'browser_ai_query',
      'gpt': 'browser_ai_query',
      'deepseek': 'browser_ai_query',
      'claude': 'browser_ai_query',
      'browser_ai': 'browser_ai_query',
      'mcp': 'mcp.read',
      'whatsapp': 'whatsapp.open_chat',
      'telegram': 'telegram.open_chat',
      'tg': 'telegram.open_chat',
      'messenger': 'messenger.open_chat',
      'fb': 'messenger.open_chat',
      'facebook': 'messenger.open_chat',
      'contactos': 'whatsapp.contacts',
      'compartir': 'whatsapp.share_file',
      'enviar_archivo': 'whatsapp.share_file',
      'alarma': 'device.set_alarm',
      'set_alarm': 'device.set_alarm',
      'despertador': 'device.set_alarm',
      'inspeccionar': 'dev.inspect_app',
      'inspect_app': 'dev.inspect_app',
      'diagnostico': 'dev.diagnostics',
      'diagnostics': 'dev.diagnostics',
      'adb': 'dev.adb',
      'benchmark': 'dev.run_benchmark',
      'run_benchmark': 'dev.run_benchmark',
    },
  );

  static const _builtinDefs = <ToolDefinition>[
    ..._toolDefinitions0,
    ..._toolDefinitions1,
    ..._toolDefinitions2,
    ..._toolDefinitions3,
    ..._toolDefinitions4,
    ..._toolDefinitions5,
  ];

  /// Resuelve [name] (con alias) al registro canónico; null si no existe.
  ToolDefinition? lookup(String name) => _byName[_aliases[name] ?? name];

  /// Normaliza solo identidades registradas; no modifica nombres de herramientas remotas.
  String canonicalName(String raw) {
    final name = raw.trim();
    final exact = lookup(name);
    if (exact != null) return exact.name;
    final lower = name.toLowerCase();
    for (final entry in _aliases.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    for (final key in _byName.keys) {
      if (key.toLowerCase() == lower) return key;
    }
    return name;
  }

  bool isKnown(String name) => lookup(name) != null;

  Iterable<ToolDefinition> get all => _byName.values;
}

/// Veredicto de la política para una llamada a herramienta.
