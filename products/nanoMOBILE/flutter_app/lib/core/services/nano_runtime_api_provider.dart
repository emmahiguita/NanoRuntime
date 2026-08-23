import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nano_runtime_api.dart';

/// Provider del puente nativo (NanoRuntimeApi). INYECTADO — ningún widget ni
/// servicio debe usar `NanoRuntimeApi.instance` directo; se consume por aquí
/// (DIP). El singleton interno se expone una vez como dependencia inyectable.
final nanoRuntimeApiProvider = Provider<NanoRuntimeApi>((ref) {
  return NanoRuntimeApi.instance;
});
