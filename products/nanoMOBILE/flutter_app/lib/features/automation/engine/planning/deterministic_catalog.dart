/// Catálogo determinista — flujos CONOCIDOS para objetivos comunes.
///
/// R0: el catálogo solo resuelve navegación claramente expresada. Mencionar
/// "Bluetooth" NO equivale a pedir abrirlo, y nunca equivale a activar/apagar
/// un switch.
library;

import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart'
    show ToolCall;
import 'package:nanoai/features/automation/engine/execution/goal_verifier.dart'
    show GoalExpectation;

class DeterministicFlow {
  final List<ToolCall> steps;
  final GoalExpectation? expectation;
  final bool outputProvesGoal;
  final List<String> requiredAny;
  final List<String> forbiddenAny;

  const DeterministicFlow({
    required this.steps,
    this.expectation,
    this.outputProvesGoal = false,
    this.requiredAny = const [],
    this.forbiddenAny = const [],
  });

  bool matches(String normalizedGoal, String keyword) {
    if (!normalizedGoal.contains(keyword)) return false;
    if (forbiddenAny.any(normalizedGoal.contains)) return false;
    if (requiredAny.isEmpty) return true;
    return requiredAny.any(normalizedGoal.contains);
  }
}

class DeterministicFlowCatalog {
  final Map<String, DeterministicFlow> _flows;
  const DeterministicFlowCatalog(this._flows);

  DeterministicFlow? forGoal(String goal) {
    final g = goal.trim().toLowerCase();
    for (final entry in _flows.entries) {
      if (entry.value.matches(g, entry.key)) return entry.value;
    }
    return null;
  }
}

const _openTerms = <String>[
  'abrir',
  'abre',
  'mostrar',
  'muestra',
  'ir a',
  've a',
  'entrar',
  'entra',
];

const _stateChangingTerms = <String>[
  'activar',
  'activa',
  'encender',
  'enciende',
  'habilitar',
  'habilita',
  'desactivar',
  'desactiva',
  'apagar',
  'apaga',
  'cambiar',
  'cambia',
  'toggle',
  'activado',
  'encendido',
  'estado',
];

const _notificationReadTerms = <String>[
  'leer',
  'lee',
  'listar',
  'lista',
  'mostrar',
  'muestra',
  'ver',
  'dime',
  'cuáles',
  'cuales',
];

const DeterministicFlow _bluetoothOpenFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'tap', selector: 'text=Bluetooth')],
  expectation: GoalExpectation(
    expectedPackage: 'com.android.settings',
    visibleText: 'Bluetooth',
  ),
  requiredAny: _openTerms,
  forbiddenAny: _stateChangingTerms,
);

const DeterministicFlow _wifiOpenFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'tap', selector: 'text=Wi-Fi')],
  expectation: GoalExpectation(
    expectedPackage: 'com.android.settings',
    visibleText: 'Wi-Fi',
  ),
  requiredAny: _openTerms,
  forbiddenAny: _stateChangingTerms,
);

const DeterministicFlow _notificationReadFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'notifications')],
  // El resultado es el snapshot que Android devolvio; no necesita inferir un
  // estado visual posterior. Un fallo del listener conserva estado failed.
  outputProvesGoal: true,
  requiredAny: _notificationReadTerms,
);

const DeterministicFlowCatalog defaultDeterministicCatalog =
    DeterministicFlowCatalog({
      'bluetooth': _bluetoothOpenFlow,
      'wi-fi': _wifiOpenFlow,
      'wifi': _wifiOpenFlow,
      'ajustes': DeterministicFlow(
        steps: [ToolCall(tool: 'tap', selector: 'text=Ajustes')],
        expectation: GoalExpectation(visibleText: 'Ajustes'),
        requiredAny: _openTerms,
      ),
      'chrome': DeterministicFlow(
        steps: [ToolCall(tool: 'launch_app', selector: 'com.android.chrome')],
        expectation: GoalExpectation(expectedPackage: 'com.android.chrome'),
        requiredAny: _openTerms,
      ),
      'notificaciones': _notificationReadFlow,
      'notificación': _notificationReadFlow,
      'volver': DeterministicFlow(steps: [ToolCall(tool: 'back')]),
      'atrás': DeterministicFlow(steps: [ToolCall(tool: 'back')]),
    });
