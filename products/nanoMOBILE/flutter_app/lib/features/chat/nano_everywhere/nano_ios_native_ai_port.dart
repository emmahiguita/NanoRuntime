import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'nano_ai_models.dart';

/// Implementación nativa para iOS de [NanoNativeAiPort].
///
/// QUÉ HACE: Realiza handoff de prompts hacia aplicaciones de IA en iOS.
/// CÓMO SE CONECTA: Intenta esquemas de URL oficiales (chatgpt://, claude://)
/// y degrada ordenadamente a la hoja de compartir del sistema (UIActivityViewController).
/// POR QUÉ: iOS no permite intents arbitrarios entre apps; respeta el sandbox
/// mediante APIs públicas oficiales sin simular éxito ficticio.
class NanoIosNativeAiPort implements NanoNativeAiPort {
  const NanoIosNativeAiPort();

  @override
  Future<bool> sharePrompt(String androidPackage, String prompt) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) return false;

    // 1. Intento por esquema de URL de la app de destino si está instalada
    final scheme = _resolveScheme(androidPackage, cleanPrompt);
    if (scheme != null) {
      final uri = Uri.parse(scheme);
      try {
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        // Fallback a share sheet si la app no está registrada en el sistema
      }
    }

    // 2. Fallback de interoperabilidad: hoja de compartir estándar de iOS
    try {
      final result = await Share.share(cleanPrompt);
      return result.status == ShareResultStatus.success;
    } catch (_) {
      return false;
    }
  }

  /// Mapea identificadores de apps conocidas a sus Custom URL Schemes en iOS.
  String? _resolveScheme(String packageOrApp, String prompt) {
    final encoded = Uri.encodeComponent(prompt);
    final lower = packageOrApp.toLowerCase();
    if (lower.contains('chatgpt') || lower.contains('openai')) {
      return 'chatgpt://?prompt=$encoded';
    }
    if (lower.contains('claude') || lower.contains('anthropic')) {
      return 'claude://';
    }
    return null;
  }
}
