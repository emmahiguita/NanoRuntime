part of 'deterministic_catalog.dart';

// Flujos existentes en su orden original; no crea acciones nuevas.
const _deterministicEntries0 = <String, DeterministicFlow>{
  'bluetooth': _bluetoothOpenFlow,
  'wi-fi': _wifiOpenFlow,
  'wifi': _wifiOpenFlow,
  'ajustes': DeterministicFlow(
    steps: [
      ToolCall(tool: 'open_system', args: {'destination': 'settings'}),
    ],
    expectation: GoalExpectation(expectedPackage: 'com.android.settings'),
    requiredAny: _openTerms,
  ),
  'configuración': DeterministicFlow(
    steps: [
      ToolCall(tool: 'open_system', args: {'destination': 'settings'}),
    ],
    expectation: GoalExpectation(expectedPackage: 'com.android.settings'),
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
  'volver': DeterministicFlow(
    steps: [ToolCall(tool: 'back')],
    outputProvesGoal: true,
  ),
  'atrás': DeterministicFlow(
    steps: [ToolCall(tool: 'back')],
    outputProvesGoal: true,
  ),
  'volver atrás': DeterministicFlow(
    steps: [ToolCall(tool: 'back')],
    outputProvesGoal: true,
  ),
  'baja': _scrollDownFlow,
  'bajar': _scrollDownFlow,
  'sube': _scrollUpFlow,
  'subir': _scrollUpFlow,
  'escribir': DeterministicFlow(
    steps: [
      ToolCall(tool: 'write', selector: 'editable=true', text: 'Prueba NanoAI'),
    ],
    outputProvesGoal: true,
  ),
  'contactos': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.contacts')],
    outputProvesGoal: true,
  ),
  'contacto': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.contacts')],
    outputProvesGoal: true,
  ),
  'desde llamadas': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.send_message')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  // W10: "busca a PERSONA en whatsapp" / "abre whatsapp y busca a PERSONA"
  // La partícula " a " tras el verbo buscar indica búsqueda de PERSONA
  // ── WhatsApp: buscar contacto y abrir conversación ────────────────────
  // 'busca a (Nombre)' y 'buscar a (Nombre)' → resuelve el contacto y abre WhatsApp.
  // requiredAny: solo aplica si el goal menciona 'whatsapp'.
  'busca a': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.open_chat')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'buscar a': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.open_chat')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),

  // ── WhatsApp: abrir chat ───────────────────────────────────────────────
  // 'abre el chat de (Nombre)' → open_chat; el coordinator inyecta contacto.
  'abre el chat de': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.open_chat')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp', 'chat'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'abrir el chat de': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.open_chat')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp', 'chat'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'abre chat de': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.open_chat')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp', 'chat'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'abrir chat de': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.open_chat')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp', 'chat'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'chat': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.open_chat')],
    expectation: GoalExpectation(expectedPackage: 'com.whatsapp'),
  ),

  // ── WhatsApp: enviar mensaje ───────────────────────────────────────────
  // 'envíale a (Nombre) (Texto)' / 'escríbele a (Nombre) (Texto)' →
  // send_message. El coordinator extrae contacto y texto del goal.
  'envíale a': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.send_message')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'enviale a': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.send_message')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'escríbele a': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.send_message')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'escribele a': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.send_message')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'mándale a': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.send_message')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  'mandale a': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.send_message')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
  // ── WhatsApp: enviar fotos, documentos y archivos multimedia ──────────
  // 'envíale una foto a (Contacto) (ruta)' / 'envíale un documento a (Contacto)'
  'envíale una foto': DeterministicFlow(
    steps: [ToolCall(tool: 'whatsapp.share_file')],
    outputProvesGoal: true,
    requiredAny: ['whatsapp'],
    forbiddenAny: ['youtube', 'google', 'spotify', 'netflix', 'chrome'],
  ),
};
