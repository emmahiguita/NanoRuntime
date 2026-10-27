// business_studio_screen.dart
//
// QUÉ HACE:
// Enrutador y fachada de compatibilidad hacia NanoBusinessScreen.
//
// CÓMO FUNCIONA:
// - Redirige transparentemente cualquier invocación hacia la experiencia unificada por pestañas [NanoBusinessScreen].
// - Garantiza compatibilidad hacia atrás con rutas y referencias anteriores sin duplicar interfaz.
//
// POR QUÉ:
// Elimina 500+ líneas de código redundante e inconsistente aplicando DRY y SOLID (< 50 líneas).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../business/nano_business_screen.dart';

class BusinessStudioScreen extends ConsumerWidget {
  const BusinessStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const NanoBusinessScreen();
  }
}
