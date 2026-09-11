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
  steps: [
    ToolCall(tool: 'open_system', args: {'destination': 'bluetooth_settings'}),
  ],
  // OEM-agnostic: no se hardcodea com.android.settings; el intent oficial abre
  // la pantalla de Bluetooth y el verifier comprueba el texto visible.
  expectation: GoalExpectation(visibleText: 'Bluetooth'),
  requiredAny: _openTerms,
  forbiddenAny: _stateChangingTerms,
);

const DeterministicFlow _wifiOpenFlow = DeterministicFlow(
  steps: [
    ToolCall(tool: 'open_system', args: {'destination': 'wifi_settings'}),
  ],
  expectation: GoalExpectation(visibleText: 'Wi-Fi'),
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

const _listFilesTerms = <String>[
  'archivo',
  'directorio',
  'fichero',
  'carpeta',
];

/// "lista los archivos" → ls de la raíz del rootfs. El listado (stdout factual
/// de `ls`) ES la respuesta; no hay postcondición de estado que verificar.
const DeterministicFlow _listFilesFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'linux.list', text: '/')],
  outputProvesGoal: true,
  requiredAny: _listFilesTerms,
);

/// T2.10 — navegación: scroll. Deliberadamente se excluyen términos de estado
/// (volumen/brillo/sonido) para que "baja el volumen" NO dispare un scroll.
const _scrollStateTerms = <String>[
  'volumen',
  'brillo',
  'sonido',
  'temperatura',
  'opacidad',
];

const DeterministicFlow _scrollDownFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'scroll', args: {'direction': 'down'})],
  forbiddenAny: _scrollStateTerms,
);

const DeterministicFlow _scrollUpFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'scroll', args: {'direction': 'up'})],
  forbiddenAny: _scrollStateTerms,
);

/// "lee la pantalla" / "qué dice la pantalla" → leer contenido visible (read-only).
/// El snapshot de accesibilidad ES la respuesta (`outputProvesGoal`): no hay
/// postcondición de estado que verificar, solo leer lo observado.
const _readScreenTerms = <String>[
  'lee',
  'leer',
  'ver',
  'muestra',
  'mostrar',
  'dice',
  'dime',
  'qué hay',
  'que hay',
  'read',
  'resume',
  'resumen',
  'resumir',
];

const DeterministicFlow _readScreenFlow = DeterministicFlow(
  steps: [ToolCall(tool: 'read_screen')],
  outputProvesGoal: true,
  requiredAny: _readScreenTerms,
);

const _newTabFlow = DeterministicFlow(
  steps: [
    ToolCall(
      tool: 'open_url',
      text: 'https://www.google.com',
      args: {'url': 'https://www.google.com', 'packageName': 'com.android.chrome'},
    ),
  ],
  expectation: GoalExpectation(expectedPackage: 'com.android.chrome'),
);

const _closeTabFlow = DeterministicFlow(
  steps: [
    ToolCall(
      tool: 'tap',
      args: {'target': 'com.android.chrome:id/close_button'},
      selector: 'com.android.chrome:id/close_button',
    ),
  ],
);

const _reloadPageFlow = DeterministicFlow(
  steps: [
    ToolCall(
      tool: 'swipe',
      args: {'x1': 540, 'y1': 300, 'x2': 540, 'y2': 900, 'durationMs': 350},
    ),
  ],
);

const DeterministicFlowCatalog defaultDeterministicCatalog =
    DeterministicFlowCatalog({
      'bluetooth': _bluetoothOpenFlow,
      'wi-fi': _wifiOpenFlow,
      'wifi': _wifiOpenFlow,
      'ajustes': DeterministicFlow(
        steps: [
          ToolCall(tool: 'open_system', args: {'destination': 'settings'}),
        ],
        expectation: GoalExpectation(visibleText: 'Ajustes'),
        requiredAny: _openTerms,
      ),
      'chrome': DeterministicFlow(
        steps: [ToolCall(tool: 'launch_app', selector: 'com.android.chrome')],
        expectation: GoalExpectation(expectedPackage: 'com.android.chrome'),
        requiredAny: _openTerms,
      ),
      'nueva pestaña': _newTabFlow,
      'abrir pestaña': _newTabFlow,
      'cerrar pestaña': _closeTabFlow,
      'cierra la pestaña': _closeTabFlow,
      'recargar página': _reloadPageFlow,
      'recarga la página': _reloadPageFlow,
      'actualizar página': _reloadPageFlow,
      'notificaciones': _notificationReadFlow,
      'notificación': _notificationReadFlow,
      'pantalla': _readScreenFlow,
      'screen': _readScreenFlow,
      'página': _readScreenFlow,
      'pagina': _readScreenFlow,
      'artículo': _readScreenFlow,
      'articulo': _readScreenFlow,
      'web': _readScreenFlow,
      'archivo': _listFilesFlow,
      'directorio': _listFilesFlow,
      'fichero': _listFilesFlow,
      'carpeta': _listFilesFlow,
      'volver': DeterministicFlow(steps: [ToolCall(tool: 'back')]),
      'atrás': DeterministicFlow(steps: [ToolCall(tool: 'back')]),
      'baja': _scrollDownFlow,
      'bajar': _scrollDownFlow,
      'sube': _scrollUpFlow,
      'subir': _scrollUpFlow,
    });
