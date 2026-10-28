import '../domain/automation_goal.dart';
import '../domain/prepared_automation_goal.dart';
import '../engine/execution/goal_verifier.dart';
import '../engine/execution/tool_call.dart';
import '../engine/perception/nano_snapshot.dart';

/// Abre la exportación oficial del chat observado. El coordinador ya existente
/// ejecuta y verifica cada paso; no lee bases privadas ni inventa el historial.
abstract final class WhatsAppChatExportPreparer {
  /// Exige una conversación real y única. La selección de multimedia y el
  /// guardado pertenecen al diálogo oficial; no se elige un destino externo.
  static PreparedAutomationGoal prepare(NanoSnapshot? snapshot) {
    final pkg = snapshot?.package;
    if (snapshot == null ||
        snapshot.truncated ||
        !const {'com.whatsapp', 'com.whatsapp.w4b'}.contains(pkg)) {
      throw const FormatException(
        'Abre la conversación en WhatsApp y pide exportarla desde el búho.',
      );
    }
    final headers = snapshot.visibleNodes
        .where(
          (node) =>
              node.packageName == pkg &&
              node.id == '$pkg:id/conversation_contact_name' &&
              node.text.trim().isNotEmpty,
        )
        .toList();
    final editors = snapshot.visibleNodes
        .where(
          (node) =>
              node.packageName == pkg &&
              node.id == '$pkg:id/entry' &&
              node.editable &&
              !node.password,
        )
        .toList();
    if (headers.length != 1 ||
        editors.length != 1 ||
        headers.single.windowId != editors.single.windowId ||
        headers.single.rootIdentity.isEmpty ||
        headers.single.rootIdentity != editors.single.rootIdentity) {
      throw const FormatException(
        'No se identifica un chat abierto con certeza. No se inició exportación.',
      );
    }
    final menus = snapshot.visibleNodes
        .where(
          (node) =>
              node.packageName == pkg &&
              node.windowId == headers.single.windowId &&
              node.rootIdentity == headers.single.rootIdentity &&
              const {'Más opciones', 'More options'}.contains(node.description),
        )
        .toList();
    if (menus.length != 1) {
      throw const FormatException(
        'No se identifica el menú oficial de este chat.',
      );
    }
    final finalLabel = menus.single.description == 'More options'
        ? 'Without media'
        : 'Sin archivos';
    final guard = {
      'contextGuard': {
        'package': pkg,
        'windowId': headers.single.windowId,
        'rootIdentity': headers.single.rootIdentity,
        'headerId': headers.single.id,
        'headerText': headers.single.text,
      },
    };
    // Selectores semánticos observados en WhatsApp instalado. Si otra versión
    // cambia sus controles, falla el paso y no pulsa otra opción por posición.
    final more = 'pkg=$pkg;text/=^(Más|More)\$';
    final export = 'pkg=$pkg;text/=^(Exportar chat|Export chat)\$';
    final noMedia = 'pkg=$pkg;text/=^(Sin archivos|Without media)\$';
    return PreparedAutomationGoal(
      AutomationGoal(
        text:
            'Abrir exportación oficial de «${headers.single.text}». '
            'Elige Sin archivos para obtener texto limpio y después guardar. '
            'Aún no se ha guardado ni compartido el historial.',
        expectation: GoalExpectation(
          expectedPackage: pkg,
          visibleText: finalLabel,
        ),
      ),
      plan: [
        ToolCall(
          tool: 'tap',
          args: guard,
          selector: 'pkg=$pkg;desc/=^(Más opciones|More options)\$',
          expect: {'package': pkg, 'appear': more},
        ),
        ToolCall(
          tool: 'tap',
          args: guard,
          selector: more,
          expect: {'package': pkg, 'appear': export},
        ),
        ToolCall(
          tool: 'tap',
          args: guard,
          selector: export,
          expect: {'package': pkg, 'appear': noMedia},
        ),
      ],
    );
  }
}
