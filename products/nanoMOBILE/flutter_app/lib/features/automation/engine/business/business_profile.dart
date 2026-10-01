// business_profile.dart
//
// QUÉ HACE: representa el contrato versionado y neutral al canal de un negocio.
// CÓMO: persiste plantilla, sector, intents, flujos, reglas, FAQ y herramientas.
// POR QUÉ: separa datos reales del negocio de la política operativa del agente.

import 'business_dialogue.dart';
import 'business_faq.dart';
import 'business_rule.dart';

final class BusinessProfile {
  static const currentSchema = 'nano.business.v1';

  final String schemaVersion;
  final String templateId;
  final String sector;
  final String locale;
  final String timezone;
  final String currency;
  final List<String> intents;
  final List<String> tools;
  final List<String> blockedAutomation;
  final List<BusinessFaq> faq;
  final List<BusinessDialogue> dialogues;
  final List<BusinessRule> rules;
  final String handoffMessage;
  final double handoffConfidence;
  final bool autoReply;
  final int maxToolSteps;
  final int approvalAmount;
  final int revision;

  const BusinessProfile({
    this.schemaVersion = currentSchema,
    this.templateId = '',
    this.sector = '',
    this.locale = 'es-CO',
    this.timezone = 'America/Bogota',
    this.currency = 'COP',
    this.intents = const [],
    this.tools = const [],
    this.blockedAutomation = const [],
    this.faq = const [],
    this.dialogues = const [],
    this.rules = const [],
    this.handoffMessage = 'Voy a pasar tu consulta a una persona del equipo.',
    this.handoffConfidence = 0.70,
    this.autoReply = true,
    this.maxToolSteps = 4,
    this.approvalAmount = 500000,
    this.revision = 1,
  });

  bool get isConfigured =>
      templateId.trim().isNotEmpty && sector.trim().isNotEmpty;

  factory BusinessProfile.fromJson(
    Map<String, dynamic> json,
  ) => BusinessProfile(
    schemaVersion: (json['schemaVersion'] as String?) ?? currentSchema,
    templateId: (json['templateId'] as String?)?.trim() ?? '',
    sector: (json['sector'] as String?)?.trim() ?? '',
    locale: (json['locale'] as String?)?.trim() ?? 'es-CO',
    timezone: (json['timezone'] as String?)?.trim() ?? 'America/Bogota',
    currency: (json['currency'] as String?)?.trim() ?? 'COP',
    intents: _strings(json['intents']),
    tools: _strings(json['tools']),
    blockedAutomation: _strings(json['blockedAutomation']),
    faq: _maps(json['faq']).map(BusinessFaq.fromJson).toList(),
    dialogues: _maps(json['dialogues']).map(BusinessDialogue.fromJson).toList(),
    rules: _maps(json['rules']).map(BusinessRule.fromJson).toList(),
    handoffMessage:
        (json['handoffMessage'] as String?)?.trim() ??
        'Voy a pasar tu consulta a una persona del equipo.',
    handoffConfidence: (json['handoffConfidence'] as num?)?.toDouble() ?? 0.70,
    autoReply: json['autoReply'] != false,
    maxToolSteps: (json['maxToolSteps'] as num?)?.toInt() ?? 4,
    approvalAmount: (json['approvalAmount'] as num?)?.toInt() ?? 500000,
    revision: (json['revision'] as num?)?.toInt() ?? 1,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'templateId': templateId,
    'sector': sector,
    'locale': locale,
    'timezone': timezone,
    'currency': currency,
    'intents': intents,
    'tools': tools,
    'blockedAutomation': blockedAutomation,
    'faq': [for (final item in faq) item.toJson()],
    'dialogues': [for (final item in dialogues) item.toJson()],
    'rules': [for (final item in rules) item.toJson()],
    'handoffMessage': handoffMessage,
    'handoffConfidence': handoffConfidence,
    'autoReply': autoReply,
    'maxToolSteps': maxToolSteps,
    'approvalAmount': approvalAmount,
    'revision': revision,
  };

  BusinessProfile copyWith({
    String? templateId,
    String? sector,
    String? locale,
    String? timezone,
    String? currency,
    List<String>? intents,
    List<String>? tools,
    List<String>? blockedAutomation,
    List<BusinessFaq>? faq,
    List<BusinessDialogue>? dialogues,
    List<BusinessRule>? rules,
    String? handoffMessage,
    double? handoffConfidence,
    bool? autoReply,
    int? maxToolSteps,
    int? approvalAmount,
    int? revision,
  }) => BusinessProfile(
    schemaVersion: schemaVersion,
    templateId: templateId ?? this.templateId,
    sector: sector ?? this.sector,
    locale: locale ?? this.locale,
    timezone: timezone ?? this.timezone,
    currency: currency ?? this.currency,
    intents: intents ?? this.intents,
    tools: tools ?? this.tools,
    blockedAutomation: blockedAutomation ?? this.blockedAutomation,
    faq: faq ?? this.faq,
    dialogues: dialogues ?? this.dialogues,
    rules: rules ?? this.rules,
    handoffMessage: handoffMessage ?? this.handoffMessage,
    handoffConfidence: handoffConfidence ?? this.handoffConfidence,
    autoReply: autoReply ?? this.autoReply,
    maxToolSteps: maxToolSteps ?? this.maxToolSteps,
    approvalAmount: approvalAmount ?? this.approvalAmount,
    revision: revision ?? this.revision,
  );
}

List<String> _strings(Object? raw) => [
  for (final value in raw is List ? raw : const <Object?>[])
    if (value is String && value.trim().isNotEmpty) value.trim(),
];

List<Map<String, dynamic>> _maps(Object? raw) => [
  for (final value in raw is List ? raw : const <Object?>[])
    if (value is Map) value.cast<String, dynamic>(),
];
