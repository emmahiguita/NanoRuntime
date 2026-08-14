import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/kali_manager.dart';
import '../services/terminal_dependencies.dart';

/// Dueño compartido del manager Kali real dentro del runtime de terminal.
/// Se expone como provider para que la UI pueda mostrar cobertura instalada
/// sin duplicar estado ni inventar datos.
final kaliProvider = Provider<KaliManager?>((ref) {
  return TerminalDependencies.instance.kali;
});
