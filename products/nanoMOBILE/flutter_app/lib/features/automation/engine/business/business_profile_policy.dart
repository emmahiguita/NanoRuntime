// business_profile_policy.dart
//
// Evalúa FAQ y políticas de entrega a humano antes de redactar una respuesta.
// No ejecuta herramientas declaradas: esas solo pueden correr mediante ToolRouter.

import 'business_profile.dart';
import 'business_text_matcher.dart';

typedef BusinessProfilePolicyReply = ({
  String text,
  List<String> suggestions,
  bool needsHuman,
});

BusinessProfilePolicyReply? resolveBusinessProfilePolicy(
  String message,
  BusinessProfile profile,
) {
  if (!profile.isConfigured) return null;
  final normalized = normalizeText(message);
  if (normalized.isEmpty) return null;

  // Las acciones bloqueadas nunca se delegan al modelo ni se simulan.
  for (final blocked in profile.blockedAutomation) {
    if (_matchesAny(normalized, _signals[blocked] ?? const [])) {
      return (
        text: profile.handoffMessage,
        suggestions: const ['Hablar con un asesor', 'Consultar horarios'],
        needsHuman: true,
      );
    }
  }

  // Las reglas HANDOFF se activan únicamente con señales explícitas conocidas.
  for (final rule in profile.rules) {
    if (rule.action.toUpperCase() != 'HANDOFF') continue;
    if (_matchesAny(normalized, _signals[rule.condition] ?? const [])) {
      return (
        text: profile.handoffMessage,
        suggestions: const ['Dejar mensaje', 'Ver información del negocio'],
        needsHuman: true,
      );
    }
  }

  // Una FAQ solo responde con el texto guardado por el propietario.
  for (final faq in profile.faq) {
    for (final pattern in faq.questionPatterns) {
      final key = normalizeText(pattern);
      if (key.isNotEmpty && normalized.contains(key) && faq.answer.isNotEmpty) {
        return (
          text: faq.answer,
          suggestions: const ['Ver servicios', 'Hablar con un asesor'],
          needsHuman: false,
        );
      }
    }
  }
  return null;
}

bool _matchesAny(String message, List<String> signals) =>
    signals.any((signal) => message.contains(normalizeText(signal)));

const _signals = <String, List<String>>{
  'DIAGNOSIS': ['diagnóstico', 'qué tengo', 'qué enfermedad'],
  'PRESCRIPTION': ['receta', 'recétame', 'medicamento debo tomar'],
  'SENSITIVE_MEDICAL_DATA': ['historia clínica', 'resultado médico'],
  'MEDICAL_ADVICE': ['síntomas', 'diagnóstico', 'tratamiento', 'medicamento'],
  'COMPLAINT': ['queja', 'reclamo', 'mal servicio'],
  'BILLING': ['cobro incorrecto', 'facturación', 'me cobraron'],
  'CANCELLATION': ['cancelar servicio', 'dar de baja', 'cancelación'],
};
