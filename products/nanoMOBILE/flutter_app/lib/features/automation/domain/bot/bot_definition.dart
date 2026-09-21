/// BOT-DEFINITION-05 — Entidad Raíz de Configuración de un Bot en NanoAI.
///
/// **QUÉ HACE:**
/// Consolida la identidad, rol, tono, canales, skills habilitadas, permisos
/// de seguridad y políticas de gobernanza de un bot configurable.
///
/// **CÓMO FUNCIONA:**
/// Objeto de dominio inmutable con serialización a SQLite / JSON, soportando
/// clonación mediante copyWith para edición reactiva en el Bot Studio.
///
/// **POR QUÉ:**
/// Materializa el invariante `Bot ≠ Model ≠ Channel ≠ Tools ≠ Memory`, permitiendo
/// que cualquier bot cambie de modelo o canal sin perder su identidad ni reglas.
library;

import 'dart:convert';
import '../../engine/messaging/tone_profile.dart';
import 'bot_permissions.dart';
import 'bot_role.dart';

final class BotDefinition {
  final String id;
  final String name;
  final BotRole role;
  final String description;
  final String goal;
  final ToneProfile tone;
  final bool enabled;
  final List<String> channels;
  final List<String> skillIds;
  final BotPermissions permissions;
  final Map<String, String> policies;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BotDefinition({
    required this.id,
    required this.name,
    required this.role,
    this.description = '',
    this.goal = '',
    this.tone = const ToneProfile(enabled: true, verbosity: ToneVerbosity.breve),
    this.enabled = true,
    this.channels = const ['whatsapp'],
    this.skillIds = const [],
    this.permissions = const BotPermissions(),
    this.policies = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  BotDefinition copyWith({
    String? name,
    BotRole? role,
    String? description,
    String? goal,
    ToneProfile? tone,
    bool? enabled,
    List<String>? channels,
    List<String>? skillIds,
    BotPermissions? permissions,
    Map<String, String>? policies,
    DateTime? updatedAt,
  }) {
    return BotDefinition(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      description: description ?? this.description,
      goal: goal ?? this.goal,
      tone: tone ?? this.tone,
      enabled: enabled ?? this.enabled,
      channels: channels ?? this.channels,
      skillIds: skillIds ?? this.skillIds,
      permissions: permissions ?? this.permissions,
      policies: policies ?? this.policies,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role.key,
        'description': description,
        'goal': goal,
        'tone': jsonEncode(tone.toJson()),
        'enabled': enabled ? 1 : 0,
        'channels': jsonEncode(channels),
        'skillIds': jsonEncode(skillIds),
        'permissions': jsonEncode(permissions.toMap()),
        'policies': jsonEncode(policies),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory BotDefinition.fromMap(Map<dynamic, dynamic> map) {
    ToneProfile t = const ToneProfile(enabled: true, verbosity: ToneVerbosity.breve);
    if (map['tone'] case final String raw when raw.isNotEmpty) {
      try {
        t = ToneProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    BotPermissions p = const BotPermissions();
    if (map['permissions'] case final String raw when raw.isNotEmpty) {
      try {
        p = BotPermissions.fromMap(jsonDecode(raw) as Map<dynamic, dynamic>);
      } catch (_) {}
    }

    List<String> decodeList(dynamic raw) {
      if (raw is List) return raw.whereType<String>().toList();
      if (raw is String && raw.isNotEmpty) {
        try {
          final dec = jsonDecode(raw);
          if (dec is List) return dec.whereType<String>().toList();
        } catch (_) {}
      }
      return const [];
    }

    Map<String, String> decodeMap(dynamic raw) {
      if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
      if (raw is String && raw.isNotEmpty) {
        try {
          final dec = jsonDecode(raw);
          if (dec is Map) return dec.map((k, v) => MapEntry(k.toString(), v.toString()));
        } catch (_) {}
      }
      return const {};
    }

    return BotDefinition(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Nuevo Bot',
      role: BotRole.fromKey(map['role']?.toString()),
      description: map['description']?.toString() ?? '',
      goal: map['goal']?.toString() ?? '',
      tone: t,
      enabled: map['enabled'] == 1 || map['enabled'] == true,
      channels: decodeList(map['channels']),
      skillIds: decodeList(map['skillIds']),
      permissions: p,
      policies: decodeMap(map['policies']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] is num ? (map['createdAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAt'] is num ? (map['updatedAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
