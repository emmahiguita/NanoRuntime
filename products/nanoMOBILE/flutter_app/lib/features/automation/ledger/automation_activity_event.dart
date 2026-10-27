/// Un nodo de la ruta ejecutada. «call» significa llamada iniciada; no prueba
/// efecto físico. «native» procede del intento Android observado, no del LLM.
class AutomationActivityEvent {
  const AutomationActivityEvent({
    required this.runId,
    required this.route,
    required this.state,
    required this.detail,
    required this.atMs,
    this.target = '',
    this.packageName = '',
  });
  final String runId, route, state, detail, target, packageName;
  final int atMs;

  Map<String, Object?> toJson() => {
    'runId': runId,
    'route': route,
    'state': state,
    'detail': detail,
    'atMs': atMs,
    'target': target,
    'packageName': packageName,
  };

  factory AutomationActivityEvent.fromJson(Map<String, dynamic> json) =>
      AutomationActivityEvent(
        runId: json['runId'] as String,
        route: json['route'] as String,
        state: json['state'] as String,
        detail: json['detail'] as String,
        atMs: (json['atMs'] as num).toInt(),
        target: json['target'] as String? ?? '',
        packageName: json['packageName'] as String? ?? '',
      );
}
