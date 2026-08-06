import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: NanoPlatformApp()));
}

class NanoPlatformApp extends ConsumerStatefulWidget {
  const NanoPlatformApp({super.key});
  @override ConsumerState<NanoPlatformApp> createState() => _NanoPlatformAppState();
}

class _NanoPlatformAppState extends ConsumerState<NanoPlatformApp> {
  @override
  void initState() {
    super.initState();
    // Carga persistida de ajustes en el arranque: el tema guardado se
    // aplica desde el primer frame, sin esperar a visitar Ajustes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'NanoPlatform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
