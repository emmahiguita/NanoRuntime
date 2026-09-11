/// TemporalLocationContext — Proveedor de anclaje temporal y geográfico en tiempo real.
///
/// Resuelve de forma factual y determinista:
/// - Día de la semana, día del mes, mes y año en español
/// - Hora y minuto local formateados (AM/PM)
/// - Ciudad y país configurados (Medellín, Colombia por defecto o tomados del perfil del dueño)
///
/// Proporciona bloques para inyección en el prompt del LLM y helpers para PragmaticFastPath.
library;

final class TemporalLocationContext {
  const TemporalLocationContext._();

  static String dayOfWeekSpanish(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'lunes';
      case DateTime.tuesday:
        return 'martes';
      case DateTime.wednesday:
        return 'miércoles';
      case DateTime.thursday:
        return 'jueves';
      case DateTime.friday:
        return 'viernes';
      case DateTime.saturday:
        return 'sábado';
      case DateTime.sunday:
        return 'domingo';
      default:
        return '';
    }
  }

  static String monthSpanish(int month) {
    switch (month) {
      case 1:
        return 'enero';
      case 2:
        return 'febrero';
      case 3:
        return 'marzo';
      case 4:
        return 'abril';
      case 5:
        return 'mayo';
      case 6:
        return 'junio';
      case 7:
        return 'julio';
      case 8:
        return 'agosto';
      case 9:
        return 'septiembre';
      case 10:
        return 'octubre';
      case 11:
        return 'noviembre';
      case 12:
        return 'diciembre';
      default:
        return '';
    }
  }

  static String formatTime(DateTime now) {
    final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  static String formatFullDate(DateTime now) {
    final dayName = dayOfWeekSpanish(now.weekday);
    final monthName = monthSpanish(now.month);
    final capitalizedDay = dayName.isNotEmpty
        ? '${dayName[0].toUpperCase()}${dayName.substring(1)}'
        : '';
    return '$capitalizedDay, ${now.day} de $monthName de ${now.year}';
  }

  static String resolveCity({Map<String, String>? ownerFacts}) {
    if (ownerFacts != null) {
      final ciudad = ownerFacts['ciudad']?.trim();
      if (ciudad != null && ciudad.isNotEmpty) return ciudad;
      final ubicacion = ownerFacts['ubicacion']?.trim();
      if (ubicacion != null && ubicacion.isNotEmpty) return ubicacion;
    }
    return 'Medellín';
  }

  static String resolveCountry({Map<String, String>? ownerFacts}) {
    if (ownerFacts != null) {
      final pais = ownerFacts['pais']?.trim();
      if (pais != null && pais.isNotEmpty) return pais;
    }
    return 'Colombia';
  }

  /// Genera el bloque compacto de anclaje factual para el prompt del modelo local.
  static String promptBlock({DateTime? now, Map<String, String>? ownerFacts}) {
    final time = now ?? DateTime.now();
    final fullDate = formatFullDate(time);
    final timeStr = formatTime(time);
    final city = resolveCity(ownerFacts: ownerFacts);
    final country = resolveCountry(ownerFacts: ownerFacts);

    return '''
<CONTEXTO TEMPORAL Y LUGAR>
Fecha actual: $fullDate
Hora local: $timeStr
Ubicación: $city, $country
</CONTEXTO TEMPORAL Y LUGAR>''';
  }
}
