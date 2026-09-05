/// WA-NATURAL-01 — perfil de tono determinista (ToneProfile).
///
/// La configuración NO viaja como prompt enorme: los controles del dueño se
/// traducen a un bloque compacto <TONO DE RESPUESTA> con frases fijas
/// (determinista, sin inventos del LLM). Jerarquía v1: si el dueño declaró
/// <MI ESTILO> (WA-PERSONA-01, texto libre), MI ESTILO define la forma
/// principal y el tono queda como guía general — regla dicha en el propio
/// bloque, no ambigua.
///
/// Overrides por canal/conversación = WA-NATURAL-02 (la jerarquía completa
/// Global → Agente → Canal → Conversación no se construye antes de validar
/// el perfil global en dispositivo).
library;

import 'dart:convert';

import '../storage/automation_db_store_client.dart';

enum ToneWarmth { cercano, formal }

enum ToneVerbosity { breve, media, extensa }

enum ToneSales { natural, persuasivo }

/// Snapshot del perfil. `enabled=false` = el bloque no entra al prompt
/// (comportamiento histórico, cero cambios).
final class ToneProfile {
  final bool enabled;
  final ToneWarmth warmth;
  final ToneVerbosity verbosity;
  final bool emojis;
  final ToneSales sales;

  const ToneProfile({
    this.enabled = false,
    this.warmth = ToneWarmth.cercano,
    this.verbosity = ToneVerbosity.media,
    this.emojis = false,
    this.sales = ToneSales.natural,
  });

  factory ToneProfile.fromJson(Map<String, dynamic> json) => ToneProfile(
    enabled: json['enabled'] == true,
    warmth: ToneWarmth.values.asNameMap()[json['warmth']] ?? ToneWarmth.cercano,
    verbosity:
        ToneVerbosity.values.asNameMap()[json['verbosity']] ??
        ToneVerbosity.media,
    emojis: json['emojis'] == true,
    sales: ToneSales.values.asNameMap()[json['sales']] ?? ToneSales.natural,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'warmth': warmth.name,
    'verbosity': verbosity.name,
    'emojis': emojis,
    'sales': sales.name,
  };

  ToneProfile copyWith({
    bool? enabled,
    ToneWarmth? warmth,
    ToneVerbosity? verbosity,
    bool? emojis,
    ToneSales? sales,
  }) => ToneProfile(
    enabled: enabled ?? this.enabled,
    warmth: warmth ?? this.warmth,
    verbosity: verbosity ?? this.verbosity,
    emojis: emojis ?? this.emojis,
    sales: sales ?? this.sales,
  );

  /// Frases deterministas del bloque ('' si deshabilitado).
  String renderBlock() {
    if (!enabled) return '';
    final trato = switch (warmth) {
      ToneWarmth.cercano => 'cercano y amable',
      ToneWarmth.formal => 'formal y respetuoso',
    };
    final extension = switch (verbosity) {
      ToneVerbosity.breve => 'respuestas breves',
      ToneVerbosity.media => 'extensión media: ni cortas ni largas',
      ToneVerbosity.extensa => 'respuestas más desarrolladas si el tema lo pide',
    };
    final emojiLine = emojis
        ? '- Puedes usar emojis con moderación.'
        : '- Sin emojis.';
    final venta = switch (sales) {
      ToneSales.natural => 'sin presión de venta: informas y dejas decidir',
      ToneSales.persuasivo =>
        'puedes destacar beneficios y urgencia con naturalidad',
    };
    return '''
<TONO DE RESPUESTA>
Preferencias de tono del negocio:
- Trato: $trato.
- Extensión: $extension.
$emojiLine
- Venta: $venta.
Si aparece <MI ESTILO>, MI ESTILO define la forma principal; estas
preferencias son solo guía general.
</TONO DE RESPUESTA>''';
  }
}

/// Persistencia (sección `tone` del AutomationStoreDb). Mismo patrón DIP.
class ToneProfileStore {
  const ToneProfileStore();

  static const section = 'tone';

  Future<ToneProfile> load() async {
    try {
      final raw = await AutomationDbStoreClient.instance.section(section);
      if (raw == null || raw.isEmpty) return const ToneProfile();
      return ToneProfile.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } on Object {
      return const ToneProfile();
    }
  }

  Future<bool> save(ToneProfile profile) => AutomationDbStoreClient.instance
      .putSection(section, jsonEncode(profile.toJson()));
}
