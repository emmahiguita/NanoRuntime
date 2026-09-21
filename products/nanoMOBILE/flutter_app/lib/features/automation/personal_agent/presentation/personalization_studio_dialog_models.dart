/// PERSONALIZATION-STUDIO-MODELS-01 — Modelos de diálogo del estudio de estilo.
///
/// **QUÉ HACE:**
/// Define las estructuras de datos de transferencia (DTO) para resultados de
/// personalización de estilo, ejemplos, memorias y banners didácticos.
///
/// **CÓMO FUNCIONA:**
/// Estructuras inmutables que encapsulan parámetros validados entre los diálogos y la pantalla.
///
/// **POR QUÉ:**
/// Desacopla la lógica de presentación de los datos, cumpliendo con SRP de SOLID.
part of 'personalization_studio_screen.dart';

final class _StyleResult {
  const _StyleResult({
    required this.register,
    required this.relationship,
    required this.learn,
    required this.enabled,
    required this.slang,
    required this.usesName,
    required this.custom,
    required this.tone,
  });
  final String register, relationship, usesName, custom;
  final bool learn, enabled, slang;
  final ToneProfile tone;
}

final class _ExampleResult {
  const _ExampleResult({
    required this.scope,
    required this.body,
    required this.input,
    required this.verified,
    required this.enabled,
    required this.isTemplate,
    this.title = '',
    this.category = '',
    this.intent = '',
    this.incomingVariants = const [],
    this.variants = const [],
    this.responses = const [],
  });
  final String scope, body, input, title, category, intent;
  final bool verified, enabled, isTemplate;
  final List<String> incomingVariants;
  final List<String> variants;
  final List<PersonaResponseOption> responses;
}

final class _MemoryResult {
  const _MemoryResult({
    required this.scope,
    required this.key,
    required this.value,
    required this.kind,
    required this.observedAt,
    this.expiresAt,
    required this.enabled,
  });
  final String scope, key, value, kind;
  final DateTime observedAt;
  final DateTime? expiresAt;
  final bool enabled;
}

final class _Scope {
  const _Scope(this.id, this.label, {this.profile, this.conversationId});
  final String id, label;
  final RelationshipProfile? profile;
  final String? conversationId;
}

final class _ImportSelection {
  const _ImportSelection(this.indices, this.ownerVerified);
  final Set<int> indices;
  final bool ownerVerified;
}

class _LearnBanner extends StatelessWidget {
  const _LearnBanner({required this.onImport});
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cómo aprende Nano de ti',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Importa un chat de WhatsApp → revisa candidatos → acepta los que quieras. '
            'Nano usa tus respuestas reales para imitar tu registro y tono. '
            'Ningún dato sale del dispositivo ni modifica el modelo.',
            style: TextStyle(fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.file_open_outlined, size: 16),
            label: const Text(
              'Importar historial',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
}
