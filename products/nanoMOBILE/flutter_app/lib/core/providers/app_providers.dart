// ================================================================
// NanoAI — Real State Management
// 
// Este archivo es un BARREL que exporta todos los providers.
// La lógica está distribuida en archivos individuales para mejor mantenimiento.
// 
// Persistence: SharedPreferences. Reactivity: Riverpod StateNotifier.
// ================================================================

// Retrocompatibilidad: exportar modelos para referencias desde UI
// (chat_screen, settings_screen, scaffold_shell, main)
export '../models/chat_models.dart';
export '../models/catalog_models.dart';

// Exportar todos los providers individuales
export 'settings_provider.dart';
export 'chat_provider.dart';
export 'dashboard_provider.dart';
export '../../features/models/application/models_provider.dart';
export 'rootfs_provider.dart';
export 'kali_provider.dart';
