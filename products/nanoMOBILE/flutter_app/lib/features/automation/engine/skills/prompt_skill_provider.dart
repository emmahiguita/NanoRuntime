import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prompt_skill_store.dart';

/// Instancia compartida entre el administrador y el generador de chat.
final promptSkillStoreProvider = Provider<PromptSkillStore>((ref) {
  return PromptSkillStore();
});
