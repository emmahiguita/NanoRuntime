import 'package:flutter/foundation.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';

/// Contrato abstracto para manejadores dinámicos de herramientas en Nano.
abstract class IToolHandler {
  List<String> get supportedTools;
  bool supports(String toolName) => supportedTools.map((t) => t.toLowerCase()).contains(toolName.toLowerCase());
  Future<String> execute(ToolCall call);
}

/// Contrato abstracto para el registro y descubrimiento dinámico de herramientas.
///
/// Aplica el Principio de Abierto/Cerrado (OCP): permite registrar nuevos
/// manejadores de herramientas (MCP, Shizuku, Linux, Apps Android, etc.)
/// sin modificar el código de orquestación o del despachador principal.
abstract class IDynamicToolRegistry {
  void registerHandler(IToolHandler handler);
  void unregisterHandler(String toolName);
  IToolHandler? findHandlerFor(String toolName);
  List<String> get registeredTools;
  bool supportsTool(String toolName);
}

/// Implementación concreta y limpia del registro dinámico de herramientas.
class DynamicToolRegistry implements IDynamicToolRegistry {
  DynamicToolRegistry();

  final Map<String, IToolHandler> _handlers = {};

  @override
  void registerHandler(IToolHandler handler) {
    for (final tool in handler.supportedTools) {
      _handlers[tool.toLowerCase()] = handler;
    }
  }

  @override
  void unregisterHandler(String toolName) {
    _handlers.remove(toolName.toLowerCase());
  }

  @override
  IToolHandler? findHandlerFor(String toolName) {
    final name = toolName.toLowerCase();
    if (_handlers.containsKey(name)) {
      return _handlers[name];
    }
    for (final handler in _handlers.values) {
      if (handler.supports(name)) {
        return handler;
      }
    }
    return null;
  }

  @override
  List<String> get registeredTools => List.unmodifiable(_handlers.keys);

  @override
  bool supportsTool(String toolName) => findHandlerFor(toolName) != null;

  /// Ejecuta de forma segura un [ToolCall] buscando su manejador registrado.
  Future<String> dispatchCall(ToolCall call) async {
    final handler = findHandlerFor(call.tool);
    if (handler == null) {
      return '[unsupported] No hay manejador registrado para la herramienta "${call.tool}".';
    }
    try {
      return await handler.execute(call);
    } catch (e, stack) {
      debugPrint('Error en ToolHandler (${call.tool}): $e\n$stack');
      return '[error] Excepción al ejecutar "${call.tool}": $e';
    }
  }
}
