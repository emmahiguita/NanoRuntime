/// SKILL-01 — SkillStore: persistencia de drafts y aprobaciones de skills.
/// Mismo patrón DIP del resto del módulo: lógica pura en memoria +
/// persistencia desacoplada (producción = shared_preferences JSON).
///
/// Un nuevo draft de la misma acción reemplaza al anterior (la evidencia
/// más reciente gana); una aprobación es durable hasta que el usuario la
/// revoque explícitamente con [revoke].
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'skill.dart';
import 'verified_skill.dart';

abstract interface class SkillStore {
  /// Guarda (o reemplaza) el draft de una skill.
  Future<void> saveDraft(Skill skill);

  /// Draft por id de skill; null si nunca se extrajo.
  Skill? draft(String skillId);

  /// Todos los drafts pendientes de aprobación.
  List<Skill> allDrafts();

  /// Aprueba explícitamente un draft (hecho humano). No-op sin draft.
  Future<void> approve(String skillId, {DateTime? at});

  /// Rechaza un draft (se descarta; no queda nada ejecutable).
  Future<void> reject(String skillId);

  /// Skills aprobadas por el usuario.
  List<VerifiedSkill> approved();

  /// Revoca una aprobación (la skill vuelve a ser inerte).
  Future<void> revoke(String skillId);
}

/// Núcleo en memoria (puro). Los subtipos aportan persistencia (DIP).
abstract class _SkillCore implements SkillStore {
  _SkillCore({this.maxDrafts = defaultMaxDrafts});

  static const int defaultMaxDrafts = 32;

  final int maxDrafts;

  final Map<String, Skill> _drafts = {};
  final Map<String, VerifiedSkill> _approved = {};

  @override
  Future<void> saveDraft(Skill skill) async {
    if (skill.id.isEmpty || skill.steps.isEmpty) return;
    _drafts[skill.id] = skill;
    if (_drafts.length > maxDrafts) {
      // Evictar el draft más antiguo (menor extractedAt).
      String? oldest;
      DateTime oldestAt = DateTime.now().toUtc();
      for (final entry in _drafts.entries) {
        if (entry.value.extractedAt.isBefore(oldestAt)) {
          oldest = entry.key;
          oldestAt = entry.value.extractedAt;
        }
      }
      if (oldest != null) _drafts.remove(oldest);
    }
    _markDirty();
  }

  @override
  Skill? draft(String skillId) => _drafts[skillId];

  @override
  List<Skill> allDrafts() => List.unmodifiable(_drafts.values);

  @override
  Future<void> approve(String skillId, {DateTime? at}) async {
    final skill = _drafts.remove(skillId);
    if (skill == null) return;
    _approved[skillId] = VerifiedSkill(
      skill: skill,
      approvedAt: (at ?? DateTime.now()).toUtc(),
    );
    _markDirty();
  }

  @override
  Future<void> reject(String skillId) async {
    if (_drafts.remove(skillId) == null) return;
    _markDirty();
  }

  @override
  List<VerifiedSkill> approved() => List.unmodifiable(_approved.values);

  @override
  Future<void> revoke(String skillId) async {
    if (_approved.remove(skillId) == null) return;
    _markDirty();
  }

  /// Snapshot serializable para persistencia.
  Map<String, Object?> _snapshot() => {
    'drafts': [for (final s in _drafts.values) s.toJson()],
    'approved': [for (final v in _approved.values) v.toJson()],
  };

  void _hydrate(Map<String, Object?> raw) {
    for (final s in (raw['drafts'] as List?) ?? const []) {
      final skill = Skill.fromJson((s as Map).cast<String, dynamic>());
      if (skill.id.isEmpty || skill.steps.isEmpty) continue;
      _drafts[skill.id] = skill;
    }
    for (final v in (raw['approved'] as List?) ?? const []) {
      final verified = VerifiedSkill.fromJson(
        (v as Map).cast<String, dynamic>(),
      );
      if (verified.skill.id.isEmpty) continue;
      _approved[verified.skill.id] = verified;
    }
  }

  void _markDirty();
}

/// Store en memoria (preview). Determinista, sin persistencia.
class MemorySkillStore extends _SkillCore {
  MemorySkillStore({super.maxDrafts});

  @override
  void _markDirty() {
    // Sin persistencia.
  }
}

/// Persistencia en shared_preferences (JSON). Producción.
class SharedPrefsSkillStore extends _SkillCore {
  static const _key = 'automation.skill_store.v1';

  SharedPrefsSkillStore({super.maxDrafts});

  @override
  void _markDirty() {
    unawaited(_write());
  }

  Future<void> _write() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_snapshot()));
  }

  /// Hidrata el estado persistido (una vez, al arrancar el provider).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        _hydrate(map);
      }
    } on Object {
      // Store corrupto o esquema viejo: arrancar limpio (fail-closed).
    }
  }
}
