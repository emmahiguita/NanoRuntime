/// Utilidad pura para normalizar y formatear números telefónicos a formato E.164.
///
/// QUÉ HACE:
/// - Limpia caracteres no numéricos (+, -, espacios, paréntesis).
/// - Deduce el prefijo de país si el usuario ingresó un número local (ej. Colombia +57).
/// - Valida longitud estándar de números telefónicos internacionales (7 a 15 dígitos).
///
/// POR QUÉ:
/// - Garantiza que los enlaces wa.me/<número> abran el chat correcto sin fallos (< 60 líneas).
final class PhoneNumberSanitizer {
  PhoneNumberSanitizer._();

  /// Código de país por defecto para números móviles locales de 10 dígitos (Colombia).
  static const String defaultCountryCode = '57';

  /// Normaliza una cadena de texto a un número apto para Click to Chat (E.164 sin signo +).
  static String sanitizeForWhatsApp(String rawPhone) {
    if (rawPhone.trim().isEmpty) return '';

    var clean = rawPhone.trim();
    final hasPlus = clean.startsWith('+');
    clean = clean.replaceAll(RegExp(r'\D'), '');

    if (clean.isEmpty) return '';

    // Si ya tenía '+' explícito, conservamos el número completo con su código de país
    if (hasPlus) return clean;

    // Números celulares colombianos (10 dígitos comenzando por 3)
    if (clean.length == 10 && clean.startsWith('3')) {
      return '$defaultCountryCode$clean';
    }

    // Si tiene entre 7 y 9 dígitos locales, adjunta código por defecto
    if (clean.length >= 7 && clean.length <= 9) {
      return '$defaultCountryCode$clean';
    }

    return clean;
  }

  /// Verifica si un número formateado cumple con la longitud internacional E.164.
  static bool isValidE164(String sanitizedPhone) {
    return sanitizedPhone.length >= 7 && sanitizedPhone.length <= 15;
  }
}
