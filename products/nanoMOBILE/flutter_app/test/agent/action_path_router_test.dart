import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/action_path_router.dart';
import 'package:nanoai/features/automation/engine/agent_tool_dispatcher.dart';

/// Tests del ActionPathRouter (C6): elige el mecanismo más eficiente — nunca
/// Accessibility cuando hay Intent/Linux para la tarea.
void main() {
  group('ActionPathRouter', () {
    final noLinux = ActionPathRouter();
    final withLinux = ActionPathRouter(linuxAvailable: () => true);
    final withIntent = ActionPathRouter(intentAvailable: () => true);

    test('tap/write/back → Accessibility (mecanismo actual de UI)', () {
      final r = noLinux.route(const ToolCall(tool: 'tap', selector: 'text=Bluetooth'));
      expect(r.path, ExecutionPath.accessibility);
      expect(noLinux.route(const ToolCall(tool: 'back')).path,
          ExecutionPath.accessibility);
      expect(noLinux.route(const ToolCall(tool: 'write')).path,
          ExecutionPath.accessibility);
    });

    test('notificaciones → herramienta estructurada (canal, sin UI)', () {
      final r = noLinux.route(const ToolCall(tool: 'notifications'));
      expect(r.path, ExecutionPath.structuredTool);
    });

    test('abrir app con Intent disponible → androidIntent', () {
      final r = withIntent.route(const ToolCall(tool: 'launch_app', text: 'settings'));
      expect(r.path, ExecutionPath.androidIntent);
    });

    test('abrir app sin Intent → Accessibility (degradación honesta)', () {
      final r = noLinux.route(const ToolCall(tool: 'launch_app'));
      expect(r.path, ExecutionPath.accessibility);
      expect(r.reason, contains('Sin Intent'));
    });

    test('leer archivo con Linux disponible → linux (NO abrir Files app)',
        () {
      final r = withLinux.route(const ToolCall(tool: 'read_file', text: '/sdcard/x'));
      expect(r.path, ExecutionPath.linux);
      expect(r.reason, contains('subsistema Linux'));
    });

    test('leer archivo sin Linux → Accessibility (fallback)', () {
      final r = noLinux.route(const ToolCall(tool: 'read_file'));
      expect(r.path, ExecutionPath.accessibility);
    });

    test('goal que menciona analizar + tool de alto nivel → linux si '
        'disponible', () {
      final r = withLinux.route(
        const ToolCall(tool: 'analyze', text: '/sdcard/proyecto'),
        goal: 'encuentra un proyecto descargado y analízalo',
      );
      expect(r.path, ExecutionPath.linux);
    });

    test('goal sin señal de archivos → Accessibility por defecto', () {
      final r = withLinux.route(
        const ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
        goal: 'abre ajustes y vuelve',
      );
      expect(r.path, ExecutionPath.accessibility);
    });
  });
}
