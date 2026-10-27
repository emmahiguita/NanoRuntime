import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

void main() {
  testWidgets(
    'notification event consumers share one broadcast EventChannel stream',
    (tester) async {
      final automationConsumer = NanoRuntimeApi().notificationEvents;
      final messagingCenterConsumer = NanoRuntimeApi.instance.notificationEvents;

      expect(identical(automationConsumer, messagingCenterConsumer), isTrue);
      expect(automationConsumer.isBroadcast, isTrue);
    },
  );
}
