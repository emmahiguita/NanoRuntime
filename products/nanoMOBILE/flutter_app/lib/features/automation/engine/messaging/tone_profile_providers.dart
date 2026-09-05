/// WA-NATURAL-01 — providers del perfil de tono. Entra en la barrera global
/// de hidratación y se lee EN VIVO en cada borrador (cambiar un control
/// aplica desde el siguiente mensaje).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tone_profile.dart';

final toneProfileStoreProvider = Provider<ToneProfileStore>((ref) {
  return const ToneProfileStore();
});

final class ToneProfileNotifier extends StateNotifier<ToneProfile> {
  ToneProfileNotifier(this._store) : super(const ToneProfile());

  final ToneProfileStore _store;
  Future<void>? _loading;

  Future<void> get ready => _loading ??= _load();

  Future<void> _load() async {
    try {
      state = await _store.load();
    } on Object {
      // Perfil corrupto: defaults (deshabilitado = cero cambios).
    }
  }

  Future<void> update(ToneProfile next) async {
    state = next;
    await _store.save(next);
  }
}

final toneProfileNotifierProvider =
    StateNotifierProvider<ToneProfileNotifier, ToneProfile>((ref) {
      final notifier = ToneProfileNotifier(
        ref.watch(toneProfileStoreProvider),
      );
      notifier.ready;
      return notifier;
    });
