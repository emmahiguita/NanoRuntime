part of 'deterministic_catalog.dart';

// Definiciones originales compartidas: navegación y lectura conservan sus restricciones.
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
  'consultar',
  'consulta',
];

const DeterministicFlow _bluetoothOpenFlow = DeterministicFlow(
  steps: [
    ToolCall(tool: 'open_system', args: {'destination': 'bluetooth_settings'}),
  ],
  expectation: GoalExpectation(expectedPackage: 'com.android.settings'),
  requiredAny: _openTerms,
  forbiddenAny: _stateChangingTerms,
);

const DeterministicFlow _wifiOpenFlow = DeterministicFlow(
  steps: [
    ToolCall(tool: 'open_system', args: {'destination': 'wifi_settings'}),
  ],
  expectation: GoalExpectation(expectedPackage: 'com.android.settings'),
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

const _listFilesTerms = <String>['archivo', 'directorio', 'fichero', 'carpeta'];

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
  steps: [
    ToolCall(tool: 'scroll', args: {'direction': 'down'}),
  ],
  forbiddenAny: _scrollStateTerms,
);

const DeterministicFlow _scrollUpFlow = DeterministicFlow(
  steps: [
    ToolCall(tool: 'scroll', args: {'direction': 'up'}),
  ],
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
      args: {
        'url': 'https://www.google.com',
        'packageName': 'com.android.chrome',
      },
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
