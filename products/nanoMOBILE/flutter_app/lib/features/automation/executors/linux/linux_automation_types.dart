import 'package:flutter/foundation.dart';

/// Tipo de entrada en el sistema de archivos Linux.
enum LinuxFileType { file, directory, symlink, socket, fifo, blockDevice, charDevice, unknown }

/// Representación estructurada de una entrada en el sistema de archivos.
@immutable
class LinuxFileEntry {
  final String path;
  final String name;
  final LinuxFileType type;
  final int sizeBytes;
  final String permissions;
  final DateTime? modifiedAt;

  const LinuxFileEntry({
    required this.path,
    required this.name,
    required this.type,
    this.sizeBytes = 0,
    this.permissions = '',
    this.modifiedAt,
  });

  bool get isDirectory => type == LinuxFileType.directory;
  bool get isFile => type == LinuxFileType.file;

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'type': type.name,
        'sizeBytes': sizeBytes,
        'permissions': permissions,
        'modifiedAt': modifiedAt?.toIso8601String(),
      };
}

/// Información de un proceso en ejecución dentro del entorno Linux.
@immutable
class LinuxProcessInfo {
  final int pid;
  final String command;
  final int memoryKb;
  final double cpuPercent;
  final String state;

  const LinuxProcessInfo({
    required this.pid,
    required this.command,
    this.memoryKb = 0,
    this.cpuPercent = 0.0,
    this.state = '',
  });

  Map<String, dynamic> toJson() => {
        'pid': pid,
        'command': command,
        'memoryKb': memoryKb,
        'cpuPercent': cpuPercent,
        'state': state,
      };
}

/// Identificador y control de un proceso rastreado en streaming.
@immutable
class LinuxProcessHandle {
  final String trackTag;
  final String command;
  final List<String> arguments;
  final DateTime startedAt;

  const LinuxProcessHandle({
    required this.trackTag,
    required this.command,
    this.arguments = const [],
    required this.startedAt,
  });

  Map<String, dynamic> toJson() => {
        'trackTag': trackTag,
        'command': command,
        'arguments': arguments,
        'startedAt': startedAt.toIso8601String(),
      };
}

/// Detalle de la verificación de una acción Linux (EXECUTED ≠ VERIFIED).
@immutable
class LinuxVerificationDetail {
  final bool verified;
  final String condition;
  final String details;
  final DateTime verifiedAt;

  const LinuxVerificationDetail({
    required this.verified,
    required this.condition,
    this.details = '',
    required this.verifiedAt,
  });

  static LinuxVerificationDetail skipped([String reason = 'No verification required']) {
    return LinuxVerificationDetail(
      verified: true,
      condition: 'skipped',
      details: reason,
      verifiedAt: DateTime.now(),
    );
  }

  static LinuxVerificationDetail failed(String condition, String details) {
    return LinuxVerificationDetail(
      verified: false,
      condition: condition,
      details: details,
      verifiedAt: DateTime.now(),
    );
  }

  static LinuxVerificationDetail satisfied(String condition, String details) {
    return LinuxVerificationDetail(
      verified: true,
      condition: condition,
      details: details,
      verifiedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'verified': verified,
        'condition': condition,
        'details': details,
        'verifiedAt': verifiedAt.toIso8601String(),
      };
}

/// Resultado tipado de una acción del motor Linux.
@immutable
class LinuxActionResult<T> {
  final T? data;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final LinuxVerificationDetail verification;

  const LinuxActionResult({
    this.data,
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
    required this.duration,
    required this.verification,
  });

  bool get ok => exitCode == 0 && verification.verified;
  bool get executedOk => exitCode == 0;
  bool get isVerified => verification.verified;

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'executedOk': executedOk,
        'isVerified': isVerified,
        'exitCode': exitCode,
        'stdout': stdout,
        'stderr': stderr,
        'durationMs': duration.inMilliseconds,
        'verification': verification.toJson(),
        if (data != null) 'data': data,
      };
}
