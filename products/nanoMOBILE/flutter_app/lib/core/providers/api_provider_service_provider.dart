import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_provider_service.dart';

final apiProviderSettingsStoreProvider = Provider<ApiProviderSettingsStore>(
  (ref) => ApiProviderSettingsStore.shared,
);

final apiProviderChatServiceProvider = Provider<ApiProviderChatService>((ref) {
  final service = ApiProviderChatService(
    store: ref.watch(apiProviderSettingsStoreProvider),
  );
  ref.onDispose(service.close);
  return service;
});
