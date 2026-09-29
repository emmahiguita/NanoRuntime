import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_provider_service.dart';

final apiProviderSettingsStoreProvider = Provider<ApiProviderSettingsStore>(
  (ref) => ApiProviderSettingsStore(),
);

final apiProviderChatServiceProvider = Provider<ApiProviderChatService>(
  (ref) => ApiProviderChatService(
    store: ref.watch(apiProviderSettingsStoreProvider),
  ),
);
