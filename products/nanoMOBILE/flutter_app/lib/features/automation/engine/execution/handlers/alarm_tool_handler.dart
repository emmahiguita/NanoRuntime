import 'package:flutter/foundation.dart';
import '../../agent_tools/registry/tool_registry.dart' show IToolHandler;
import '../../platform/nano_system_api.dart';
import '../tool_call.dart';

/// Manejador de herramientas y comandos de Alarma / Despertador del sistema.
///
/// Principios SOLID aplicados:
/// - SRP: Responsabilidad única de interpretar solicitudes de alarmas y despacharlas al subsistema de reloj nativo.
/// - OCP / LSP: Implementa [IToolHandler] para registrarse dinámicamente en el motor de herramientas sin modificar el núcleo.
/// - DIP: Depende de la abstracción [NanoSystemApi] inyectable.
class AlarmToolHandler implements IToolHandler {
  final NanoSystemApi _api;

  AlarmToolHandler({NanoSystemApi? api}) : _api = api ?? NanoSystemApi.instance;

  @override
  List<String> get supportedTools => const [
        'device.set_alarm',
        'set_alarm',
        'alarma',
        'alarm',
      ];

  @override
  bool supports(String toolName) {
    final lower = toolName.toLowerCase();
    return supportedTools.any((t) => t.toLowerCase() == lower);
  }

  @override
  Future<String> execute(ToolCall call) async {
    final args = call.args ?? const {};
    final hour = _parseInt(args['hour']) ?? 8;
    final minutes = _parseInt(args['minutes'] ?? args['minute']) ?? 0;
    final message = (args['message'] ?? args['label'] ?? 'Alarma Nano').toString();
    final weekdays = _parseWeekdays(args['weekdays'] ?? args['days']);
    final skipUi = args['skipUi'] != false;

    return setAlarm(
      hour: hour,
      minutes: minutes,
      message: message,
      weekdays: weekdays,
      skipUi: skipUi,
    );
  }

  /// Procesa comandos directos de usuario vía `@alarma <expresion_natural>`.
  /// Ejemplo: `@alarma a las 8 am los 5 primeros dias de la semana`
  Future<String> handleCommand(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty || input == '?' || input.toLowerCase() == 'ayuda') {
      return 'Sintaxis: @alarma <hora> [días] [mensaje]. '
          'Ejemplos: "@alarma 8:00 am lun-vie", "@alarma 7:30 los 5 primeros dias de la semana", "@alarma 6:45 mensaje Correr".';
    }

    int hour = 8;
    int minutes = 0;
    List<int>? weekdays;
    String message = 'Alarma Nano';

    // 1. Extraer hora (ej: "8 am", "08:00", "7:30 pm", "20:15")
    final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false).firstMatch(input);
    if (timeMatch != null) {
      int parsedHour = int.parse(timeMatch.group(1)!);
      minutes = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final meridiem = timeMatch.group(3)?.toLowerCase();

      if (meridiem == 'pm' && parsedHour < 12) parsedHour += 12;
      if (meridiem == 'am' && parsedHour == 12) parsedHour = 0;
      hour = parsedHour.clamp(0, 23);
      minutes = minutes.clamp(0, 59);
    }

    // 2. Extraer días (ej: "5 primeros dias", "lunes a viernes", "fin de semana")
    final lower = input.toLowerCase();
    if (lower.contains('5 primeros') ||
        lower.contains('primeros 5') ||
        lower.contains('lun-vie') ||
        lower.contains('lunes a viernes') ||
        lower.contains('entre semana') ||
        lower.contains('dias de semana')) {
      weekdays = [1, 2, 3, 4, 5]; // Lun - Vie (ISO)
    } else if (lower.contains('fin de semana') || lower.contains('sab-dom') || lower.contains('sabado y domingo')) {
      weekdays = [6, 7]; // Sáb - Dom
    } else if (lower.contains('todos los dias') || lower.contains('diario')) {
      weekdays = [1, 2, 3, 4, 5, 6, 7];
    } else {
      final detectedDays = <int>{};
      if (lower.contains('lun')) detectedDays.add(1);
      if (lower.contains('mar')) detectedDays.add(2);
      if (lower.contains('mie') || lower.contains('mié')) detectedDays.add(3);
      if (lower.contains('jue')) detectedDays.add(4);
      if (lower.contains('vie')) detectedDays.add(5);
      if (lower.contains('sab') || lower.contains('sáb')) detectedDays.add(6);
      if (lower.contains('dom')) detectedDays.add(7);
      if (detectedDays.isNotEmpty) weekdays = detectedDays.toList()..sort();
    }

    // 3. Extraer mensaje si existe etiqueta "mensaje" o "para"
    final msgMatch = RegExp(r'(?:mensaje|para|titulo|título)\s+(.+)$', caseSensitive: false).firstMatch(input);
    if (msgMatch != null) {
      message = msgMatch.group(1)!.trim();
    }

    return setAlarm(
      hour: hour,
      minutes: minutes,
      message: message,
      weekdays: weekdays,
      skipUi: true,
    );
  }

  /// Ejecuta la acción nativa de programar alarma a través de [NanoSystemApi].
  Future<String> setAlarm({
    required int hour,
    int minutes = 0,
    String message = 'Alarma Nano',
    List<int>? weekdays,
    bool skipUi = true,
  }) async {
    final result = await _api.setSystemAlarm(
      hour: hour,
      minutes: minutes,
      message: message,
      weekdays: weekdays,
      skipUi: skipUi,
    );

    if (result == null) {
      return '[alarma_error] No se pudo conectar con el subsistema nativo de alarmas.';
    }

    if (result['success'] == true) {
      final timeFormatted = '${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      final daysStr = weekdays != null && weekdays.isNotEmpty
          ? ' para ${_formatWeekdays(weekdays)}'
          : ' (una sola vez)';
      final note = message.isNotEmpty ? ' [Mensaje: "$message"]' : '';
      return '[alarma] Alarma programada a las $timeFormatted$daysStr.$note';
    }

    return '[alarma_error] Falló al programar la alarma: ${result['error']}';
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  List<int>? _parseWeekdays(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((e) => _parseInt(e)).whereType<int>().toList();
    }
    return null;
  }

  String _formatWeekdays(List<int> days) {
    if (listEquals(days, [1, 2, 3, 4, 5])) return 'Lunes a Viernes';
    if (listEquals(days, [6, 7])) return 'Fines de semana';
    if (days.length == 7) return 'Todos los días';
    const names = {1: 'Lun', 2: 'Mar', 3: 'Mié', 4: 'Jue', 5: 'Vie', 6: 'Sáb', 7: 'Dom'};
    return days.map((d) => names[d] ?? '$d').join(', ');
  }
}
