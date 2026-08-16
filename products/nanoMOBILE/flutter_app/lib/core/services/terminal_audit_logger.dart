import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../utils/security_utils.dart';

/// Structured, privacy-aware audit logger for terminal orchestration.
///
/// Goals:
/// - correlate user command -> dispatcher -> PTY/native/shell result;
/// - record exit/error codes and duration;
/// - keep logs useful without leaking full app-private paths or secrets.
class TerminalAuditLogger {
  TerminalAuditLogger({File? sink, bool enabled = true})
    : _sink = sink,
      _enabled = enabled;

  final File? _sink;
  final bool _enabled;
  int _seq = 0;

  String nextTraceId(String source) {
    _seq = (_seq + 1) & 0x7fffffff;
    return '${source}_${DateTime.now().millisecondsSinceEpoch}_$_seq';
  }

  void event(
    String name, {
    required String layer,
    String? traceId,
    String? command,
    List<String>? argv,
    int? exitCode,
    int? byteCount,
    Duration? duration,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> data = const {},
  }) {
    if (!_enabled) return;
    final payload = <String, Object?>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'event': name,
      'layer': layer,
      if (traceId != null) 'traceId': traceId,
      if (command != null) 'command': _sanitize(command),
      if (argv != null) 'argv': argv.map(_sanitize).toList(),
      if (exitCode != null) 'exitCode': exitCode,
      if (byteCount != null) 'byteCount': byteCount,
      if (duration != null) 'durationMs': duration.inMilliseconds,
      if (error != null) 'error': _sanitize(error.toString()),
      if (stackTrace != null) 'stack': _shortStack(stackTrace),
      ...data.map((k, v) => MapEntry(k, _sanitizeValue(v))),
    };
    final line = jsonEncode(payload);
    debugPrint('[terminal-audit] $line');
    final sink = _sink;
    if (sink != null) {
      try {
        sink.parent.createSync(recursive: true);
        _rotateIfNeeded(sink);
        sink.writeAsStringSync('$line\n', mode: FileMode.append, flush: false);
      } catch (_) {
        // Logging must never break terminal execution.
      }
    }
  }

  T timedSync<T>(
    String name, {
    required String layer,
    String? traceId,
    String? command,
    List<String>? argv,
    required T Function() body,
  }) {
    final sw = Stopwatch()..start();
    event(
      '$name.start',
      layer: layer,
      traceId: traceId,
      command: command,
      argv: argv,
    );
    try {
      final result = body();
      event('$name.ok', layer: layer, traceId: traceId, duration: sw.elapsed);
      return result;
    } catch (e, st) {
      event(
        '$name.error',
        layer: layer,
        traceId: traceId,
        duration: sw.elapsed,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<T> timed<T>(
    String name, {
    required String layer,
    String? traceId,
    String? command,
    List<String>? argv,
    required Future<T> Function() body,
  }) async {
    final sw = Stopwatch()..start();
    event(
      '$name.start',
      layer: layer,
      traceId: traceId,
      command: command,
      argv: argv,
    );
    try {
      final result = await body();
      event('$name.ok', layer: layer, traceId: traceId, duration: sw.elapsed);
      return result;
    } catch (e, st) {
      event(
        '$name.error',
        layer: layer,
        traceId: traceId,
        duration: sw.elapsed,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null || value is num || value is bool) return value;
    if (value is Iterable) return value.map(_sanitizeValue).toList();
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', _sanitizeValue(item)));
    }
    return _sanitize(value.toString());
  }

  static String _sanitize(String value) {
    // AND-015 FIX: Usa SecurityUtils compartido en lugar de implementación duplicada
    return SecurityUtils.sanitizeInput(value);
  }

  static String _shortStack(StackTrace stackTrace) {
    return stackTrace.toString().split('\n').take(6).map(_sanitize).join('\n');
  }

  static void _rotateIfNeeded(File file) {
    if (!file.existsSync()) return;
    const maxBytes = 512 * 1024;
    if (file.lengthSync() <= maxBytes) return;
    final rotated = File('${file.path}.1');
    try {
      if (rotated.existsSync()) rotated.deleteSync();
      file.renameSync(rotated.path);
    } catch (_) {}
  }
}
