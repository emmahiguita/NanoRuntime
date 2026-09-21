part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-ACTIONS-DIALOGS — Diálogos de Información y Ayuda.
///
/// **QUÉ HACE:**
/// Gestiona notificaciones SnackBar, confirmaciones modales,
/// guías de aprendizaje y formato de metadatos de fechas y archivos.
///
/// **CÓMO FUNCIONA:**
/// Implementa diálogos adaptativos con AlertDialog, SelectableText y Clipboard
/// para educar sobre privacidad y formatos JSON/TXT/CSV de WhatsApp.
///
/// **POR QUÉ:**
/// Desacopla la lógica de retroalimentación e información estática del flujo de datos,
/// manteniendo cada archivo estrictamente menor a 200 líneas de código.
extension _PersonalizationStudioDialogs on _PersonalizationStudioScreenState {
  void _notice(String text) {
    if (mounted && text.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text, style: const TextStyle(fontSize: 11)), behavior: SnackBarBehavior.floating));
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Confirmar')),
          ],
        ),
      ) ==
      true;

  Future<void> _infoDialog(
    String title,
    Widget content, {
    List<Widget>? extraActions,
  }) => showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        ...?extraActions,
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cerrar')),
      ],
    ),
  );

  void _showHowItLearns() => _infoDialog(
    '¿Cómo aprende Nano de ti?',
    const SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('1. Importa TXT/CSV/JSON de WhatsApp.', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Nano extrae pares: mensaje recibido → tu respuesta.'),
            SizedBox(height: 8),
            Text('2. Revisa y acepta solo los candidatos que quieras.', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Nada se guarda sin tu confirmación explícita.'),
            SizedBox(height: 8),
            Text('3. En cada respuesta futura el retriever recupera tus ejemplos.', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Longitud, registro y tono son los que tú usaste. Ningún dato sale del dispositivo.', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    ),
  );

  void _showPrivacyNote() => _infoDialog(
    'Privacidad de datos',
    const SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Text(
          'Todo queda en el dispositivo. Nada se envía a servidores ni al proveedor del modelo. '
          'Ejemplos y memorias se guardan en SQLite local. Puedes eliminar cualquier registro '
          'desde las pestañas. Retirar un lote elimina solo sus registros, no datos manuales.',
        ),
      ),
    ),
  );

  void _formatHelp() {
    final sample = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'messages': [
        {'role': 'contact', 'text': 'Hola, ¿cómo vas?', 'timestamp': 1788793200000},
        {'role': 'owner', 'text': 'Bien, gracias. ¿Y tú?', 'timestamp': 1788793201000},
      ],
      'memories': [
        {'type': 'stablePreference', 'key': 'contacto', 'value': 'Prefiere mensajes breves', 'observedAt': 1788793200000},
      ],
      'templates': [
        {'incoming': 'Consulta de referencia', 'reply': '¿Cuál referencia buscas?'},
      ],
    });
    _infoDialog(
      'Formatos de importación',
      SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('JSON v1: un contacto por archivo. CSV: role,text,timestamp. TXT: WhatsApp con tu nombre exacto.'),
              const SizedBox(height: 12),
              SelectableText(sample),
            ],
          ),
        ),
      ),
      extraActions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: sample));
            _notice('Ejemplo JSON copiado.');
          },
          child: const Text('Copiar JSON'),
        ),
      ],
    );
  }

  Map<dynamic, dynamic> _batchMetadata(dynamic raw) {
    if (raw is Map) return raw;
    if (raw is! String) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  String _batchDate(dynamic raw) {
    final value = raw is num ? raw.toInt() : int.tryParse('');
    if (value == null) return 'Fecha no disponible';
    try {
      return '';
    } on ArgumentError {
      return 'Fecha no disponible';
    }
  }
}
