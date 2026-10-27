import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/performance/nano_performance_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NanoPerformanceEngine', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.nanoai/performance'),
            (MethodCall call) async {
              methodCalls.add(call);
              switch (call.method) {
                case 'setMode':
                  return true;
                case 'getMode':
                  return 'turbo';
                case 'getThermalStatus':
                  return {
                    'status': 2,
                    'name': 'MODERATE',
                    'threadScale': 0.75,
                  };
                case 'reportWorkDuration':
                  return true;
                case 'getCapabilities':
                  return {
                    'adpfSupported': true,
                    'thermalSupported': true,
                    'currentMode': 'balanced',
                    'cpuCores': 8,
                  };
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.nanoai/performance'),
            null,
          );
    });

    test('NanoThermalStatus maps raw integers correctly', () {
      expect(NanoThermalStatus.fromInt(0), NanoThermalStatus.none);
      expect(NanoThermalStatus.fromInt(1), NanoThermalStatus.light);
      expect(NanoThermalStatus.fromInt(2), NanoThermalStatus.moderate);
      expect(NanoThermalStatus.fromInt(3), NanoThermalStatus.severe);
      expect(NanoThermalStatus.fromInt(4), NanoThermalStatus.critical);
      expect(NanoThermalStatus.fromInt(5), NanoThermalStatus.emergency);
      expect(NanoThermalStatus.fromInt(6), NanoThermalStatus.shutdown);
      expect(NanoThermalStatus.fromInt(-1), NanoThermalStatus.unknown);
      expect(NanoThermalStatus.fromInt(99), NanoThermalStatus.unknown);
    });

    test('ThermalEvent parses map correctly', () {
      final map = {
        'status': 2,
        'name': 'MODERATE',
        'threadScale': 0.75,
      };
      final event = ThermalEvent.fromMap(map);
      expect(event.status, NanoThermalStatus.moderate);
      expect(event.rawStatus, 2);
      expect(event.name, 'MODERATE');
      expect(event.threadScale, 0.75);
    });

    test('computeAdaptiveThreads scales correctly and respects clamp', () {
      final engine = NanoPerformanceEngine.instance;

      // Normal (scale 1.0) -> 4 threads
      expect(engine.computeAdaptiveThreads(baseThreads: 4, threadScale: 1.0), 4);
      // Moderate (scale 0.75) -> 3 threads
      expect(engine.computeAdaptiveThreads(baseThreads: 4, threadScale: 0.75), 3);
      // Severe (scale 0.50) -> 2 threads
      expect(engine.computeAdaptiveThreads(baseThreads: 4, threadScale: 0.50), 2);
      // Critical (scale 0.25) -> 1 thread
      expect(engine.computeAdaptiveThreads(baseThreads: 4, threadScale: 0.25), 1);
      // Emergency/Shutdown (scale 0.0) -> minimum 1 thread (clamp to survive)
      expect(engine.computeAdaptiveThreads(baseThreads: 4, threadScale: 0.0), 1);
    });

    test('setMode and getMode interact via MethodChannel', () async {
      final engine = NanoPerformanceEngine.instance;

      final ok = await engine.setMode(NanoPerformanceMode.turbo);
      expect(ok, isTrue);
      expect(methodCalls.last.method, 'setMode');
      expect(methodCalls.last.arguments, {'mode': 'turbo'});

      final mode = await engine.getMode();
      expect(mode, NanoPerformanceMode.turbo);
      expect(methodCalls.last.method, 'getMode');
    });

    test('acquireSession sets turbo and restores previous mode on dispose', () async {
      final engine = NanoPerformanceEngine.instance;

      final session = await engine.acquireSession(mode: NanoPerformanceMode.turbo);
      expect(session.mode, NanoPerformanceMode.turbo);

      await session.reportWorkDuration(const Duration(milliseconds: 25));
      expect(methodCalls.last.method, 'reportWorkDuration');
      expect(methodCalls.last.arguments, {'durationNs': 25000000});

      await session.dispose();
      expect(methodCalls.last.method, 'setMode');
    });

    test('getThermalStatus fetches and updates latestThermal', () async {
      final engine = NanoPerformanceEngine.instance;

      final event = await engine.getThermalStatus();
      expect(event.status, NanoThermalStatus.moderate);
      expect(event.threadScale, 0.75);
      expect(engine.latestThermal.status, NanoThermalStatus.moderate);
    });
  });
}
