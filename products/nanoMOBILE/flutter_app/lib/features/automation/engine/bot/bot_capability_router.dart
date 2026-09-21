/// BOT-CAPABILITY-ROUTER-01 — Enrutador de Herramientas y Gobernanza por Bot.
///
/// **QUÉ HACE:**
/// Intercepta las solicitudes de ejecución de herramientas de un bot, validando
/// que pertenezcan a sus skills activas y cumplan con su matriz de permisos (RBAC).
///
/// **CÓMO FUNCIONA:**
/// Cruza las herramientas registradas en AgentToolDispatcher con los BotPermissions
/// y las skills habilitadas del BotDefinition, bloqueando llamadas no autorizadas.
///
/// **POR QUÉ:**
/// Garantiza el principio de menor privilegio: un bot comercial jamás podrá ejecutar
/// comandos de terminal aunque el LLM intente emitirlos en su respuesta.
library;

import 'package:flutter/foundation.dart';
import '../../application/bot/bot_skills_catalog.dart';
import '../../domain/bot/bot_definition.dart';
import '../execution/agent_tool_dispatcher.dart';
import '../execution/tool_registry.dart' show PolicyVerdict;

final class BotCapabilityRouter {
  final BotDefinition bot;
  final AgentToolDispatcher dispatcher;

  BotCapabilityRouter({
    required this.bot,
    AgentToolDispatcher? dispatcher,
  }) : dispatcher = dispatcher ?? AgentToolDispatcher();

  /// Conjunto de nombres de herramientas que este bot tiene permitido invocar.
  Set<String> get authorizedTools {
    final allowedBySkills = <String>{};
    for (final skillId in bot.skillIds) {
      final skill = BotSkillsCatalog.getSkill(skillId);
      if (skill != null) {
        allowedBySkills.addAll(skill.toolNames);
      }
    }
    return allowedBySkills.where((tool) => bot.permissions.canExecute(tool)).toSet();
  }

  /// Verifica si una herramienta específica puede ser ejecutada por este bot.
  bool isAuthorized(String toolName) {
    if (!bot.permissions.canExecute(toolName)) return false;
    for (final skillId in bot.skillIds) {
      final skill = BotSkillsCatalog.getSkill(skillId);
      if (skill != null && skill.toolNames.contains(toolName)) {
        return true;
      }
    }
    return false;
  }

  /// Ejecuta la herramienta de forma segura con verificación previa de gobernanza.
  Future<ToolOutcome> executeTool(ToolCall call) async {
    if (!isAuthorized(call.tool)) {
      debugPrint('[BotCapabilityRouter] Bloqueo de seguridad: Bot "${bot.name}" no tiene permiso para "${call.tool}".');
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: 'Herramienta "${call.tool}" no autorizada para el bot "${bot.name}". Requiere permiso específico en su perfil.',
        executionStatus: ToolExecutionStatus.failed,
      );
    }

    try {
      return await dispatcher.runToolGuarded(call);
    } catch (e) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: 'Error en la ejecución de "${call.tool}": $e',
        executionStatus: ToolExecutionStatus.failed,
      );
    }
  }

  /// Genera un resumen factual de las herramientas activas para el planificador.
  String buildCapabilitiesPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('Capacidades y herramientas autorizadas para ${bot.name}:');
    for (final skillId in bot.skillIds) {
      final skill = BotSkillsCatalog.getSkill(skillId);
      if (skill == null) continue;
      final activeTools = skill.toolNames.where((t) => bot.permissions.canExecute(t)).toList();
      if (activeTools.isNotEmpty) {
        buffer.writeln('- ${skill.name}: [${activeTools.join(', ')}] — ${skill.description}');
      }
    }
    return buffer.toString();
  }
}
