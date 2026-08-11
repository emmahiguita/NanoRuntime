import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VncStatus {
  final bool running;
  final bool reachable;
  final int port;

  const VncStatus({
    required this.running,
    required this.reachable,
    required this.port,
  });

  bool get ready => reachable;

  static const offline = VncStatus(
    running: false,
    reachable: false,
    port: 5901,
  );

  factory VncStatus.fromMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) return offline;
    return VncStatus(
      running: raw['running'] == true,
      reachable: raw['reachable'] == true,
      port: raw['port'] as int? ?? 5901,
    );
  }
}

class PackageService {
  static const _channel = MethodChannel('com.nanoai/exec_bin');

  const PackageService();

  Future<bool> installPackages(List<String> packages) async {
    try {
      final resp = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'installPackages',
        {'packages': packages},
      );
      return resp?['installed'] == true;
    } catch (e) {
      debugPrint('[pkg] installPackages error: $e');
      return false;
    }
  }

  Future<bool> installGraphical() async {
    try {
      final resp = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'installGraphical',
        {},
      );
      return resp?['installed'] == true;
    } catch (e) {
      debugPrint('[pkg] installGraphical error: $e');
      return false;
    }
  }

  Future<int> startVnc() async {
    try {
      final resp = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'startVnc',
        {},
      );
      return resp?['port'] as int? ?? -1;
    } catch (e) {
      debugPrint('[vnc] startVnc error: $e');
      return -1;
    }
  }

  Future<VncStatus> getVncStatus() async {
    try {
      final resp = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getVncStatus',
        {},
      );
      return VncStatus.fromMap(resp);
    } catch (e) {
      debugPrint('[vnc] getVncStatus error: $e');
      return VncStatus.offline;
    }
  }

  Future<void> stopVnc() async {
    try {
      await _channel.invokeMethod('stopVnc', {});
    } catch (e) {
      debugPrint('[vnc] stopVnc error: $e');
    }
  }

  Future<void> launchXsdl() async {
    try {
      final success = await _channel.invokeMethod<bool>('launchXsdl', {});
      if (success != true) {
        throw Exception("Error launching XSDL");
      }
    } on PlatformException catch (e) {
      debugPrint('[xsdl] launch error: ${e.message}');
      throw Exception(e.message ?? "Error launching XSDL");
    }
  }
}
