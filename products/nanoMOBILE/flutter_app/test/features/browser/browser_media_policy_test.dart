import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser/domain/browser_pip_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_scripts.dart';

void main() {
  group('Browser media policy', () {
    test('does not spoof page visibility or force hidden playback', () {
      final scripts = [
        BrowserScripts.readMediaStateScript,
        BrowserScripts.pauseMediaScript,
        BrowserScripts.restoreVisibleMediaScript(
          positionSeconds: 12,
          shouldPlay: true,
        ),
      ].join('\n');

      expect(scripts, isNot(contains("defineProperty(document, 'hidden'")));
      expect(scripts, isNot(contains('visibilityState')));
      expect(scripts, isNot(contains('__nanoForcedBackground')));
    });

    test('clamps the restored playback position', () {
      final script = BrowserScripts.restoreVisibleMediaScript(
        positionSeconds: 999999,
        shouldPlay: false,
      );

      expect(script, contains('86400.000'));
      expect(script, contains('media.pause()'));
    });

    test('PiP state keeps transfer and native mode independently', () {
      const initial = BrowserPipState();
      final transferring = initial.copyWith(
        isActive: true,
        transferPending: true,
        resumePositionSeconds: 42.5,
      );
      final native = transferring.copyWith(isSystemPip: true);

      expect(native.isActive, isTrue);
      expect(native.isSystemPip, isTrue);
      expect(native.transferPending, isTrue);
      expect(native.resumePositionSeconds, 42.5);
    });
  });
}
