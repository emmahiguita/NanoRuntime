/// NanoSensitiveDataPolicy — Detección y redacción de información confidencial
///
/// Responsabilidad Única (SRP):
/// Identifica campos sensibles (contraseñas, PINs, OTPs, tokens, tarjetas)
/// y redacta su contenido antes de almacenarlo en el TranscriptLedger o logs.
library;

import '../perception/nano_snapshot.dart';

abstract final class NanoSensitiveDataPolicy {
  static final _otpRegex = RegExp(r'^\d{4,8}$');
  static final _cardRegex = RegExp(r'^\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}$');
  static final _tokenPrefixRegex = RegExp(
    r'^(ey[A-Za-z0-9_-]+\.|sk-[A-Za-z0-9]+|Bearer\s+)',
  );
  static final _passwordKeywordRegex = RegExp(
    r'(password|passwd|clave|contrasena|contraseña|secret)',
    caseSensitive: false,
  );

  /// Determina si un nodo de la interfaz de usuario es un campo confidencial.
  static bool isSensitiveNode(NanoNode? node) {
    if (node == null) return false;

    if (node.password) return true;

    final id = node.id.toLowerCase();
    final type = node.type.toLowerCase();
    final semantics =
        '${node.description} ${node.hint} ${node.stateDescription}'
            .toLowerCase();

    // Detección por tipo de widget o flags Android
    if (type.contains('password') || type.contains('pin')) return true;

    // Detección por ResourceId
    if (id.contains('password') ||
        id.contains('passwd') ||
        id.contains('clave') ||
        id.contains('pin') ||
        id.contains('otp') ||
        id.contains('cvv') ||
        id.contains('token') ||
        id.contains('secret') ||
        id.contains('card_number')) {
      return true;
    }

    // Detección por contentDescription
    if (semantics.contains('contraseña') ||
        semantics.contains('password') ||
        semantics.contains('código de seguridad') ||
        semantics.contains('pin')) {
      return true;
    }

    return false;
  }

  /// Determina si un valor de texto coincide con patrones de datos confidenciales.
  static bool isSensitiveText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return false;

    if (_otpRegex.hasMatch(clean)) return true;
    if (_cardRegex.hasMatch(clean)) return true;
    if (_tokenPrefixRegex.hasMatch(clean)) return true;
    if (_passwordKeywordRegex.hasMatch(clean)) return true;

    return false;
  }

  /// Redacta de forma segura el texto para el historial y registros.
  static String redact(
    String text, {
    NanoNode? targetNode,
    bool isExplicitSensitive = false,
  }) {
    if (text.isEmpty) return '';

    final sensitive =
        isExplicitSensitive ||
        isSensitiveNode(targetNode) ||
        isSensitiveText(text);

    if (sensitive) {
      return '[REDACTADO: ${text.length} caracteres]';
    }

    // Para textos largos no confidenciales, truncar para mantener eficiencia
    if (text.length > 60) {
      return '${text.substring(0, 57)}...';
    }

    return text;
  }
}
