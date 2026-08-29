/// Journal durable mínimo para ejecución exactly-once de commits irreversibles.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../governance/action_confirmation.dart';
import 'task_plan.dart';

enum ExecutionJournalStatus {
  planned,
  waitingConfirmation,
  executing,
  executed,
  verifying,
  verified,
  completedUnverified,
  outcomeUnknown,
  failed,
  cancelled,
}

final class ExecutionJournalEntry {
  final String runId;
  final String planSignature;
  final String goalFingerprint;
  final int currentStep;
  final String stepId;
  final ExecutionJournalStatus status;
  final bool irreversible;
  final String actionSignature;
  final String verificationState;
  final DateTime timestamp;
  final ActionConfirmation? pendingConfirmation;
  final Map<String, RequiredEvidence> evidenceByStep;

  const ExecutionJournalEntry({
    required this.runId,
    required this.planSignature,
    required this.goalFingerprint,
    required this.currentStep,
    required this.stepId,
    required this.status,
    required this.irreversible,
    required this.actionSignature,
    required this.verificationState,
    required this.timestamp,
    this.pendingConfirmation,
    this.evidenceByStep = const {},
  });

  ExecutionJournalEntry copyWith({
    ExecutionJournalStatus? status,
    String? verificationState,
    DateTime? timestamp,
    ActionConfirmation? pendingConfirmation,
  }) => ExecutionJournalEntry(
    runId: runId,
    planSignature: planSignature,
    goalFingerprint: goalFingerprint,
    currentStep: currentStep,
    stepId: stepId,
    status: status ?? this.status,
    irreversible: irreversible,
    actionSignature: actionSignature,
    verificationState: verificationState ?? this.verificationState,
    timestamp: timestamp ?? this.timestamp,
    pendingConfirmation: pendingConfirmation ?? this.pendingConfirmation,
    evidenceByStep: evidenceByStep,
  );

  Map<String, Object?> toJson() => {
    'runId': runId,
    'planSignature': planSignature,
    'goalFingerprint': goalFingerprint,
    'currentStep': currentStep,
    'stepId': stepId,
    'status': status.name,
    'irreversible': irreversible,
    'actionSignature': actionSignature,
    'verificationState': verificationState,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'pendingConfirmation': pendingConfirmation?.toJson(),
    'evidenceByStep': {
      for (final entry in evidenceByStep.entries) entry.key: entry.value.name,
    },
  };

  factory ExecutionJournalEntry.fromJson(Map<String, Object?> json) {
    final pending = json['pendingConfirmation'];
    final evidence = json['evidenceByStep'];
    return ExecutionJournalEntry(
      runId: json['runId'] as String,
      planSignature: json['planSignature'] as String,
      goalFingerprint: json['goalFingerprint'] as String,
      currentStep: json['currentStep'] as int,
      stepId: json['stepId'] as String,
      status: ExecutionJournalStatus.values.byName(json['status'] as String),
      irreversible: json['irreversible'] == true,
      actionSignature: json['actionSignature'] as String,
      verificationState: json['verificationState'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      pendingConfirmation: pending is Map
          ? ActionConfirmation.fromJson(
              pending.map((key, value) => MapEntry('$key', value)),
            )
          : null,
      evidenceByStep: evidence is Map
          ? {
              for (final entry in evidence.entries)
                '${entry.key}': RequiredEvidence.values.byName(
                  '${entry.value}',
                ),
            }
          : const {},
    );
  }
}

abstract interface class ExecutionJournal {
  Future<void> save(ExecutionJournalEntry entry);
  Future<ExecutionJournalEntry?> load(String runId);
  Future<List<ExecutionJournalEntry>> all();
  Future<ExecutionJournalEntry?> consumeConfirmation(
    ActionConfirmation confirmation,
  );
  Future<void> recoverInterrupted();
}

ExecutionJournalEntry? _consumePendingConfirmation(
  ExecutionJournalEntry? entry,
  ActionConfirmation presented,
) {
  if (entry == null ||
      entry.status != ExecutionJournalStatus.waitingConfirmation) {
    return null;
  }
  final pending = entry.pendingConfirmation;
  if (pending == null || pending.confirmationId != presented.confirmationId) {
    return null;
  }
  final consumed = pending.consumeIfAuthorizes(
    executionId: presented.executionId,
    planSignature: presented.planSignature,
    stepIndex: presented.stepIndex,
    stepId: presented.stepId,
    actionSignature: presented.actionSignature,
  );
  if (!consumed) return null;
  return entry.copyWith(
    status: ExecutionJournalStatus.planned,
    verificationState: 'confirmación consumida; acción aún no iniciada',
    timestamp: DateTime.now().toUtc(),
    pendingConfirmation: pending,
  );
}

final class SharedPreferencesExecutionJournal implements ExecutionJournal {
  static const _indexKey = 'nano.executionJournal.index.v1';
  static const _entryPrefix = 'nano.executionJournal.entry.v1.';
  static Future<void> _confirmationQueue = Future<void>.value();

  @override
  Future<void> save(ExecutionJournalEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_indexKey)?.toSet() ?? <String>{};
    ids.add(entry.runId);
    await prefs.setString('$_entryPrefix${entry.runId}', jsonEncode(entry));
    await prefs.setStringList(_indexKey, ids.toList(growable: false));
  }

  @override
  Future<ExecutionJournalEntry?> load(String runId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_entryPrefix$runId');
    if (raw == null) return null;
    try {
      return ExecutionJournalEntry.fromJson(
        (jsonDecode(raw) as Map).map((key, value) => MapEntry('$key', value)),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<List<ExecutionJournalEntry>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_indexKey) ?? const <String>[];
    final entries = <ExecutionJournalEntry>[];
    for (final id in ids) {
      final entry = await load(id);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  @override
  Future<ExecutionJournalEntry?> consumeConfirmation(
    ActionConfirmation confirmation,
  ) async {
    final previous = _confirmationQueue;
    final release = Completer<void>();
    _confirmationQueue = release.future;
    await previous;
    try {
      final claimed = _consumePendingConfirmation(
        await load(confirmation.executionId),
        confirmation,
      );
      if (claimed == null) return null;
      await save(claimed);
      return claimed;
    } finally {
      release.complete();
    }
  }

  @override
  Future<void> recoverInterrupted() async {
    for (final entry in await all()) {
      final interrupted =
          entry.irreversible &&
          (entry.status == ExecutionJournalStatus.executing ||
              entry.status == ExecutionJournalStatus.executed ||
              entry.status == ExecutionJournalStatus.verifying);
      if (!interrupted) continue;
      await save(
        entry.copyWith(
          status: ExecutionJournalStatus.outcomeUnknown,
          verificationState:
              'proceso interrumpido durante commit; requiere reconciliación',
          timestamp: DateTime.now().toUtc(),
        ),
      );
    }
  }
}

final class InMemoryExecutionJournal implements ExecutionJournal {
  final Map<String, ExecutionJournalEntry> _entries = {};

  @override
  Future<void> save(ExecutionJournalEntry entry) async {
    _entries[entry.runId] = entry;
  }

  @override
  Future<ExecutionJournalEntry?> load(String runId) async => _entries[runId];

  @override
  Future<List<ExecutionJournalEntry>> all() async =>
      List.unmodifiable(_entries.values);

  @override
  Future<ExecutionJournalEntry?> consumeConfirmation(
    ActionConfirmation confirmation,
  ) async {
    final claimed = _consumePendingConfirmation(
      _entries[confirmation.executionId],
      confirmation,
    );
    if (claimed == null) return null;
    _entries[claimed.runId] = claimed;
    return claimed;
  }

  @override
  Future<void> recoverInterrupted() async {
    for (final entry in [..._entries.values]) {
      final interrupted =
          entry.irreversible &&
          (entry.status == ExecutionJournalStatus.executing ||
              entry.status == ExecutionJournalStatus.executed ||
              entry.status == ExecutionJournalStatus.verifying);
      if (interrupted) {
        await save(
          entry.copyWith(
            status: ExecutionJournalStatus.outcomeUnknown,
            verificationState: 'interrumpido',
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }
    }
  }
}
