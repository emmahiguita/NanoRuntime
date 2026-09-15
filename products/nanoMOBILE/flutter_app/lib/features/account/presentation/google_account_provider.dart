import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/google_account_repository.dart';
import '../domain/google_account_profile.dart';

final googleAccountRepositoryProvider = Provider<GoogleAccountRepository>((ref) {
  return GoogleAccountRepository();
});

final googleAccountProvider =
    StateNotifierProvider<GoogleAccountNotifier, GoogleAccountProfile>((ref) {
  final repo = ref.watch(googleAccountRepositoryProvider);
  return GoogleAccountNotifier(repo);
});

class GoogleAccountNotifier extends StateNotifier<GoogleAccountProfile> {
  final GoogleAccountRepository _repository;
  bool _syncing = false;

  GoogleAccountNotifier(this._repository)
      : super(const GoogleAccountProfile(
          email: 'emmanuel.higuita.gomez@gmail.com',
          displayName: 'Emmanuel Higuita',
          isConnected: true,
          syncStatus: 'Conectando...',
        )) {
    _init();
  }

  bool get isSyncing => _syncing;

  Future<void> _init() async {
    final loaded = await _repository.loadProfile();
    state = loaded;
    await syncNow();
  }

  Future<bool> syncNow() async {
    if (_syncing) return true;
    _syncing = true;
    state = state.copyWith(syncStatus: 'Sincronizando...');

    final sw = Stopwatch()..start();
    final isOnline = await _repository.verifyGoogleConnectivity();
    sw.stop();

    _syncing = false;
    final now = DateTime.now();
    if (isOnline) {
      state = state.copyWith(
        isConnected: true,
        lastSynced: now,
        syncStatus: 'En línea (${sw.elapsedMilliseconds} ms)',
      );
    } else {
      state = state.copyWith(syncStatus: 'Sin conexión a Google');
    }
    await _repository.saveProfile(state);
    return isOnline;
  }

  Future<void> connectAccount({
    required String email,
    required String displayName,
  }) async {
    state = state.copyWith(
      email: email.trim(),
      displayName: displayName.trim(),
      isConnected: true,
      lastSynced: DateTime.now(),
      syncStatus: 'Conectado',
    );
    await _repository.saveProfile(state);
    await syncNow();
  }

  Future<void> disconnectAccount() async {
    state = state.copyWith(
      isConnected: false,
      syncStatus: 'Desconectado',
    );
    await _repository.saveProfile(state);
  }

  Future<void> toggleBrowserAgent(bool enabled) async {
    state = state.copyWith(browserAgentEnabled: enabled);
    await _repository.saveProfile(state);
  }

  Future<void> toggleGoogleSearch(bool enabled) async {
    state = state.copyWith(googleSearchEnabled: enabled);
    await _repository.saveProfile(state);
  }

  Future<void> toggleCloudSync(bool enabled) async {
    state = state.copyWith(cloudSyncEnabled: enabled);
    await _repository.saveProfile(state);
  }
}
