import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/mcp/mobile_automation_tool_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nano Regresion: Snapshot conserva semantica enriquecida', () {
    test(
      'NanoSnapshot.fromRaw preserva la jerarquia, depth y relaciones estructurales',
      () {
        final rawSnapshot = {
          'package': 'com.whatsapp',
          'truncated': false,
          'nodeLimitReached': false,
          'depthLimitReached': false,
          'windows': [
            {
              'windowId': 100,
              'windowType': 1,
              'displayId': 0,
              'package': 'com.whatsapp',
              'rootIdentity': '100|root|FrameLayout|0,0,1080,2400',
              'active': true,
              'focused': true,
            },
          ],
          'nodes': [
            {
              'depth': 0,
              'windowId': 100,
              'windowType': 1,
              'displayId': 0,
              'rootIdentity': '100|root|FrameLayout|0,0,1080,2400',
              'id': 'com.whatsapp:id/chat_row',
              'type': 'android.widget.RelativeLayout',
              'text': '',
              'desc': 'Fila de mensaje',
              'clickable': true,
              'editable': false,
              'scrollable': false,
              'checked': false,
              'selected': false,
              'focusable': true,
              'focused': false,
              'visible': true,
              'enabled': true,
              'package': 'com.whatsapp',
              'bounds': [0, 200, 1080, 350],
              'parentIndex': null,
              'siblingIndex': 0,
            },
            {
              'depth': 1,
              'windowId': 100,
              'windowType': 1,
              'displayId': 0,
              'rootIdentity': '100|root|FrameLayout|0,0,1080,2400',
              'id': 'com.whatsapp:id/message_text',
              'type': 'android.widget.TextView',
              'text': 'Hola Juan',
              'desc': '',
              'clickable': false,
              'editable': false,
              'scrollable': false,
              'checked': false,
              'selected': false,
              'focusable': false,
              'focused': false,
              'visible': true,
              'enabled': true,
              'package': 'com.whatsapp',
              'bounds': [40, 220, 500, 320],
              'parentIndex': 0,
              'siblingIndex': 0,
            },
          ],
        };

        final snapshot = NanoSnapshot.fromRaw(rawSnapshot);

        expect(snapshot.package, 'com.whatsapp');
        expect(snapshot.windows.length, 1);
        expect(snapshot.windows.first.windowId, 100);
        expect(snapshot.nodes.length, 2);

        final row = snapshot.nodes[0];
        final textNode = snapshot.nodes[1];

        // Verificacion de semantica enriquecida de nodo
        expect(row.depth, 0);
        expect(row.clickable, isTrue);
        expect(row.bounds.centerX, 540);
        expect(row.bounds.centerY, 275);

        expect(textNode.depth, 1);
        expect(textNode.text, 'Hola Juan');
        expect(textNode.hasExplicitParent, isTrue);
        expect(textNode.parentIndex, 0);

        // tapTargetFor debe navegar al ancestro clickable de la misma jerarquia
        final target = snapshot.tapTargetFor(textNode);
        expect(target.index, 0);
        expect(target.id, 'com.whatsapp:id/chat_row');
        expect(target.clickable, isTrue);
      },
    );

    test('preserva banderas de limites de seguridad de recorrido', () {
      final truncatedRaw = {
        'package': 'com.android.settings',
        'truncated': true,
        'nodeLimitReached': true,
        'depthLimitReached': false,
        'nodes': <Map<String, dynamic>>[],
      };

      final snap = NanoSnapshot.fromRaw(truncatedRaw);
      expect(snap.truncated, isTrue);
      expect(snap.nodeLimitReached, isTrue);
      expect(snap.depthLimitReached, isFalse);
    });
  });

  group('Nano Regresion: Acciones MCP nunca se disfrazan de lectura', () {
    test(
      'todas las herramientas mutantes declaran estrictamente readOnlyHint = false',
      () {
        final tools = MobileAutomationToolCatalog.createToolDefinitions();

        const mutatingToolNames = [
          'tap',
          'type',
          'swipe',
          'press_key',
          'launch_app',
        ];

        for (final toolName in mutatingToolNames) {
          final tool = tools.firstWhere(
            (t) => t.name == toolName,
            orElse: () => throw TestFailure(
              'Herramienta mutante  no encontrada en catalogo',
            ),
          );

          expect(
            tool.annotations.readOnlyHint,
            isFalse,
            reason:
                'VULNERABILIDAD/FALLO: La herramienta mutante "" declaro readOnlyHint = true!',
          );
        }
      },
    );

    test(
      'las herramientas con efectos colaterales de interaccion no son idempotentes a ciegas',
      () {
        final tools = MobileAutomationToolCatalog.createToolDefinitions();

        const nonIdempotentInteractiveTools = [
          'tap',
          'type',
          'swipe',
          'press_key',
        ];

        for (final toolName in nonIdempotentInteractiveTools) {
          final tool = tools.firstWhere((t) => t.name == toolName);

          expect(
            tool.annotations.idempotentHint,
            isFalse,
            reason:
                'La herramienta mutante interactiva "" no puede ser marcada como idempotentHint = true.',
          );
        }
      },
    );

    test(
      'las herramientas de inspeccion son las unicas con readOnlyHint = true e idempotentHint = true',
      () {
        final tools = MobileAutomationToolCatalog.createToolDefinitions();

        const inspectionTools = ['observe', 'verify', 'get_ledger_history'];

        for (final toolName in inspectionTools) {
          final tool = tools.firstWhere((t) => t.name == toolName);

          expect(
            tool.annotations.readOnlyHint,
            isTrue,
            reason:
                'La herramienta de inspeccion "" debe ser readOnlyHint = true.',
          );
          expect(
            tool.annotations.idempotentHint,
            isTrue,
            reason:
                'La herramienta de inspeccion "" debe ser idempotentHint = true.',
          );
        }
      },
    );
  });
}
