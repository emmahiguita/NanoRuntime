import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/platform/whatsapp_media_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsAppMediaShare Auto-Send & Return Tests', () {
    const channel = MethodChannel('com.nanoai/share');
    final methodCalls = <MethodCall>[];
    bool accessibilityMockValue = true;

    setUp(() {
      methodCalls.clear();
      accessibilityMockValue = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        switch (methodCall.method) {
          case 'openChat':
            return true;
          case 'isAccessibilityEnabled':
            return accessibilityMockValue;
          case 'openAccessibilitySettings':
            return true;
          case 'copyToCatalog':
            return '/data/user/0/nano/catalog/test.png';
          case 'shareFile':
            return true;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('openChat passes contact, text, packageName and autoSend=true by default', () async {
      const share = WhatsAppMediaShare();
      final ok = await share.openChat(
        contact: '573001234567@s.whatsapp.net',
        text: 'Hola desde Nano con retorno flash',
        packageName: 'com.whatsapp',
      );

      expect(ok, isTrue);
      expect(methodCalls, hasLength(1));
      expect(methodCalls.first.method, equals('openChat'));
      final args = methodCalls.first.arguments as Map;
      expect(args['contact'], equals('573001234567@s.whatsapp.net'));
      expect(args['text'], equals('Hola desde Nano con retorno flash'));
      expect(args['packageName'], equals('com.whatsapp'));
      expect(args['autoSend'], isTrue);
    });

    test('isAccessibilityEnabled reports correctly when active and inactive', () async {
      const share = WhatsAppMediaShare();

      accessibilityMockValue = true;
      expect(await share.isAccessibilityEnabled(), isTrue);

      accessibilityMockValue = false;
      expect(await share.isAccessibilityEnabled(), isFalse);
    });

    test('openAccessibilitySettings invokes channel method', () async {
      const share = WhatsAppMediaShare();
      final ok = await share.openAccessibilitySettings();

      expect(ok, isTrue);
      expect(methodCalls.any((call) => call.method == 'openAccessibilitySettings'), isTrue);
    });
  });
}
