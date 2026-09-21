import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/features/browser/domain/browser_credential_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_credential_vault.dart';

final browserCredentialVaultProvider = FutureProvider<BrowserCredentialVault>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return BrowserCredentialVault(prefs);
});

final browserCredentialProvider =
    StateNotifierProvider<BrowserCredentialNotifier, List<BrowserCredential>>((ref) {
  return BrowserCredentialNotifier();
});

class BrowserCredentialNotifier extends StateNotifier<List<BrowserCredential>> {
  BrowserCredentialVault? _vault;

  BrowserCredentialNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _vault = await BrowserCredentialVault.create();
    await refresh();
  }

  Future<void> refresh() async {
    _vault ??= await BrowserCredentialVault.create();
    final list = await _vault!.getAllCredentials();
    // Ordenar por última vez usado descendente
    list.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    state = list;
  }

  Future<void> saveCredential({
    required String domain,
    required String username,
    required String password,
    String? id,
  }) async {
    _vault ??= await BrowserCredentialVault.create();
    final cred = BrowserCredential(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      domain: domain,
      username: username,
      password: password,
      createdAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
    );
    await _vault!.saveCredential(cred);
    await refresh();
  }

  Future<void> deleteCredential(String id) async {
    _vault ??= await BrowserCredentialVault.create();
    await _vault!.deleteCredential(id);
    await refresh();
  }

  Future<void> updateLastUsed(String id) async {
    _vault ??= await BrowserCredentialVault.create();
    await _vault!.updateLastUsed(id);
    await refresh();
  }

  Future<List<BrowserCredential>> getCredentialsForDomain(String domain) async {
    _vault ??= await BrowserCredentialVault.create();
    return _vault!.getCredentialsForDomain(domain);
  }

  Future<void> clearAll() async {
    _vault ??= await BrowserCredentialVault.create();
    await _vault!.clearAll();
    state = [];
  }
}
