import 'dart:typed_data';
import 'nano_snapshot.dart';

/// Observacion sincronizada: jerarquia semantica y, cuando Android lo permite,
/// una captura PNG solicitada en la misma ventana temporal.
final class NanoAtomicSnapshot {
  final int protocolVersion;
  final NanoSnapshot hierarchy;
  final Uint8List? screenshotPng;
  final bool screenshotRequested;
  final bool screenshotIncluded;
  final int screenshotErrorCode;
  final String activity;
  final int width;
  final int height;
  final int rotation;
  final double? synchronizationSkewMs;

  const NanoAtomicSnapshot({
    required this.protocolVersion,
    required this.hierarchy,
    required this.screenshotPng,
    required this.screenshotRequested,
    required this.screenshotIncluded,
    required this.screenshotErrorCode,
    required this.activity,
    required this.width,
    required this.height,
    required this.rotation,
    required this.synchronizationSkewMs,
  });

  factory NanoAtomicSnapshot.fromRaw(Map<dynamic, dynamic> raw) {
    final bytes = switch (raw['screenshotPng']) {
      final Uint8List value => value,
      final List<int> value => Uint8List.fromList(value),
      final List<dynamic> value => Uint8List.fromList(
        value.whereType<num>().map((item) => item.toInt()).toList(),
      ),
      _ => null,
    };
    return NanoAtomicSnapshot(
      protocolVersion: (raw['protocolVersion'] as num?)?.toInt() ?? 0,
      hierarchy: NanoSnapshot.fromRaw(raw),
      screenshotPng: bytes,
      screenshotRequested: raw['screenshotRequested'] == true,
      screenshotIncluded: raw['screenshotIncluded'] == true,
      screenshotErrorCode: (raw['screenshotErrorCode'] as num?)?.toInt() ?? 0,
      activity: raw['activity'] as String? ?? '',
      width: (raw['width'] as num?)?.toInt() ?? 0,
      height: (raw['height'] as num?)?.toInt() ?? 0,
      rotation: (raw['rotation'] as num?)?.toInt() ?? 0,
      synchronizationSkewMs: (raw['synchronizationSkewMs'] as num?)?.toDouble(),
    );
  }
}
