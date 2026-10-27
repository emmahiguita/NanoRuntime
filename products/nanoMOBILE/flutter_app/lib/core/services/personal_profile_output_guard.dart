/// QUÉ: impide enviar etiquetas internas y volcados de perfil ante saludos.
/// CÓMO: reglas observables de formato; no pretende evaluar toda la semántica.
/// POR QUÉ: un perfil es contexto de redacción, no una respuesta al contacto.
abstract final class PersonalProfileOutputGuard {
  static final _internalTags = RegExp(
    r'</?(?:PERFIL DEL DUEÑO|DATOS DE LA PERSONA|CONTEXTO DEL TURNO|'
    r'EVIDENCIA MULTIMEDIA)(?:[:>])',
    caseSensitive: false,
  );
  static final _profileLabels = RegExp(
    r'(?:^|[\n.;])\s*(?:dueño|apodo|ocupaci[oó]n|nombre del dueño)\s*:',
    caseSensitive: false,
  );
  static final _greeting = RegExp(
    r'^(?:hola|buenas|buenos dias|buenas tardes|buenas noches|hey)'
    r'(?: (?:como (?:vas|estas|esta)|que (?:tal|mas)))?$',
  );

  /// El texto de entrada ya viene normalizado para comparar, no para enviarlo.
  static String? rejectionReason(String lexicalInput, String reply) {
    if (_internalTags.hasMatch(reply)) return 'internal_context_leak';
    // Compara también etiquetas con negrita/viñetas, sin alterar el envío.
    final plain = reply.replaceAll(RegExp(r'[*_`]+'), '');
    if (_greeting.hasMatch(lexicalInput) && _profileLabels.hasMatch(plain)) {
      return 'unsolicited_profile_dump';
    }
    return null;
  }
}
