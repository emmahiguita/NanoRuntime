/// Puerto opcional de observación: no supone que una tarea pendiente tenga PID.
abstract interface class LinuxProcessInspector {
  Map<String, Object?> inspectTracked(String tag);
}
