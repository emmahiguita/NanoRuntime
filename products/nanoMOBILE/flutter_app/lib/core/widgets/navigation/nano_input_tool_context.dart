import 'package:flutter/foundation.dart';

/// Datos de presentación del ejecutor activo. No despacha acciones ni acredita
/// conexión por mostrar un icono: [status] y [detail] explican la evidencia real.
@immutable
class NanoInputToolContext {
  const NanoInputToolContext({
    required this.name,
    required this.asset,
    required this.action,
    required this.status,
    this.target = '',
    this.detail = '',
    this.active = false,
  });
  final String name, asset, action, status, target, detail;
  final bool active;

  String get description => [
    name,
    action,
    if (target.isNotEmpty) target,
    status,
    if (detail.isNotEmpty) detail,
  ].join(' · ');

  @override
  bool operator ==(Object other) =>
      other is NanoInputToolContext &&
      (name, asset, action, status, target, detail, active) ==
          (
            other.name,
            other.asset,
            other.action,
            other.status,
            other.target,
            other.detail,
            other.active,
          );
  @override
  int get hashCode =>
      Object.hash(name, asset, action, status, target, detail, active);
}
