part of 'deterministic_catalog.dart';

// Continuación del mismo catálogo público, sin repetir claves ni herramientas.
const _deterministicEntries1 = <String, DeterministicFlow>{
  'enviale una foto': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'envíale un documento': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'enviale un documento': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'envíale un archivo': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'enviale un archivo': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'envíale una imagen': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'enviale una imagen': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'envíale un video': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'enviale un video': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'envíale un pdf': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'enviale un pdf': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'envía una foto': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'envia una foto': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'envía un documento': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'envia un documento': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),

  // ── WhatsApp: lanzar app ───────────────────────────────────────────────
  // Solo abre la app sin acción adicional.
  // forbiddenAny incluye todos los verbos de búsqueda/envío para evitar
  // que "abre whatsapp y busca a X" caiga aquí en vez de 'busca a'.
  'whatsapp': DeterministicFlow(
    steps: [
      ToolCall(tool: 'launch_app', args: {'packageName': 'com.whatsapp'}),
    ],
    expectation: GoalExpectation(expectedPackage: 'com.whatsapp'),
    forbiddenAny: [
      'contacto',
      'contactos',
      'mensaje',
      'chat',
      'busca a',
      'buscar a',
      'envíale a',
      'enviale a',
      'escríbele a',
      'escribele a',
      'mándale a',
      'mandale a',
      'abre el chat de',
      'abrir el chat de',
      'abre chat de',
      'abrir chat de',
      'foto',
      'documento',
      'archivo',
      'imagen',
      'video',
      'pdf',
    ],
  ),

  'abre ajustes, luego bluetooth, y vuelve': DeterministicFlow(
    steps: [
      ToolCall(tool: 'open_system', args: {'destination': 'settings'}),
      ToolCall(
        tool: 'open_system',
        args: {'destination': 'bluetooth_settings'},
      ),
      ToolCall(tool: 'back'),
    ],
    outputProvesGoal: true,
  ),
  'dime si bluetooth': DeterministicFlow(
    steps: [ToolCall(tool: 'device_state')],
    outputProvesGoal: true,
  ),
  'nano': DeterministicFlow(
    steps: [
      ToolCall(tool: 'launch_app', args: {'packageName': 'dev.nanoai.mobile'}),
    ],
    expectation: GoalExpectation(expectedPackage: 'dev.nanoai.mobile'),
  ),
};
