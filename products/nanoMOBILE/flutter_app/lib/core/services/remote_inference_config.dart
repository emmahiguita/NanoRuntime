/// Configuración de servidor remoto / PC para delegación de inferencia neural.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InferenceExecutionTarget {
  onDevice,
  remotePc,
}

class RemoteInferenceConfig {
  final InferenceExecutionTarget target;
  final String serverUrl;
  final String apiKey;

  const RemoteInferenceConfig({
    this.target = InferenceExecutionTarget.onDevice,
    this.serverUrl = 'http://127.0.0.1:8080',
    this.apiKey = '',
  });

  bool get isRemote => target == InferenceExecutionTarget.remotePc;
}

abstract final class RemoteInferenceSettingsStore {
  static const _targetKey = 'nano_inference_target_v1';
  static const _urlKey = 'nano_inference_server_url_v1';
  static const _apiKeySecret = 'nano_inference_api_key_v1';
  static const _secureStorage = FlutterSecureStorage();

  static Future<RemoteInferenceConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final targetStr = prefs.getString(_targetKey);
    final target = targetStr == 'remotePc'
        ? InferenceExecutionTarget.remotePc
        : InferenceExecutionTarget.onDevice;
    final url = prefs.getString(_urlKey) ?? 'http://127.0.0.1:8080';
    String apiKey = '';
    try {
      apiKey = await _secureStorage.read(key: _apiKeySecret) ?? '';
    } catch (_) {}

    return RemoteInferenceConfig(
      target: target,
      serverUrl: url,
      apiKey: apiKey,
    );
  }

  static Future<void> save({
    required InferenceExecutionTarget target,
    required String serverUrl,
    required String apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _targetKey,
      target == InferenceExecutionTarget.remotePc ? 'remotePc' : 'onDevice',
    );
    await prefs.setString(_urlKey, serverUrl.trim());
    try {
      await _secureStorage.write(key: _apiKeySecret, value: apiKey.trim());
    } catch (_) {}
  }
}

class RemoteInferenceNotifier extends StateNotifier<RemoteInferenceConfig> {
  RemoteInferenceNotifier() : super(const RemoteInferenceConfig()) {
    _init();
  }

  Future<void> _init() async {
    state = await RemoteInferenceSettingsStore.load();
  }

  Future<void> updateConfig({
    required InferenceExecutionTarget target,
    required String serverUrl,
    required String apiKey,
  }) async {
    await RemoteInferenceSettingsStore.save(
      target: target,
      serverUrl: serverUrl,
      apiKey: apiKey,
    );
    state = RemoteInferenceConfig(
      target: target,
      serverUrl: serverUrl,
      apiKey: apiKey,
    );
  }
}

final remoteInferenceConfigProvider =
    StateNotifierProvider<RemoteInferenceNotifier, RemoteInferenceConfig>(
      (ref) => RemoteInferenceNotifier(),
    );
