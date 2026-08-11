import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rootfs_manager.dart';

/// Único RootfsManager de la app: main.dart lo usa para el auto-bootstrap
/// al arrancar, y el terminal lo reusa (vía ShellExecutor) para que la
/// instalación no se duplique y el estado esté sincronizado.
final rootfsProvider = Provider<RootfsManager>((ref) => RootfsManager.instance);
