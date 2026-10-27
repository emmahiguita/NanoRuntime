/// WA-NATURAL-01 — providers del perfil de tono. Entra en la barrera global
/// de hidratación y se lee EN VIVO en cada borrador (cambiar un control
/// aplica desde el siguiente mensaje).
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tone_profile.dart';
import '../../personal_agent/application/personal_owner_profile_editor.dart';
import '../../personal_agent/application/persona_repository.dart';

final toneProfileStoreProvider = Provider<ToneProfileStore>((ref) {
  return const ToneProfileStore();
});

final businessToneProfileStoreProvider = Provider<ToneProfileStore>((ref) {
  return const ToneProfileStore(section: 'business_tone');
});

final class ToneProfileNotifier extends StateNotifier<ToneProfile> {
  ToneProfileNotifier(this._store) : super(const ToneProfile());

  final ToneProfileStore _store;
  Future<void>? _loading;
  Future<void> _writes = Future.value();

  Future<void> get ready => _loading ??= _load();

  Future<void> _load() async {
    try {
      state = await _store.load();
      if (_store.section == 'tone') {
        final owners = await PersonaRepository.instance.listPersonas(
          rethrowFailures: true,
        );
        final owner = owners.where((p) => p.personaKey == 'owner').firstOrNull;
        final raw = owner?.facts['tone'];
        if (raw != null) {
          state = ToneProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } else if (state.enabled) {
          await _saveOwnerTone(state);
        }
      }
    } on Object {
      // Perfil corrupto: defaults (deshabilitado = cero cambios).
    }
  }

  Future<void> _saveOwnerTone(ToneProfile next) =>
      PersonalOwnerProfileEditor.update({
        'tone': jsonEncode(next.toJson()),
        'styleRegister': next.warmth == ToneWarmth.formal ? 'formal' : 'close',
      });

  Future<void> update(ToneProfile next) {
    final task = _writes.then((_) async {
      await ready;
      if (_store.section == 'tone') await _saveOwnerTone(next);
      await _store.save(next);
      if (mounted) state = next;
    });
    _writes = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }
}

final toneProfileNotifierProvider =
    StateNotifierProvider<ToneProfileNotifier, ToneProfile>((ref) {
      final notifier = ToneProfileNotifier(ref.watch(toneProfileStoreProvider));
      notifier.ready;
      return notifier;
    });

/// Perfil exclusivo de Negocios; nunca modifica el estilo del agente Personal.
final businessToneProfileNotifierProvider =
    StateNotifierProvider<ToneProfileNotifier, ToneProfile>((ref) {
      final notifier = ToneProfileNotifier(
        ref.watch(businessToneProfileStoreProvider),
      );
      notifier.ready;
      return notifier;
    });
