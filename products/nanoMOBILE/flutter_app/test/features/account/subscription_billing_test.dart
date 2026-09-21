import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/account/application/subscription_controller.dart';
import 'package:nanoai/features/account/domain/subscription_plan.dart';
import 'package:nanoai/features/account/infrastructure/google_play_billing_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GooglePlayBillingAdapter adapter;
  late SubscriptionController controller;

  setUp(() {
    adapter = GooglePlayBillingAdapter();
    controller = SubscriptionController(adapter);
  });

  tearDown(() {
    controller.dispose();
  });

  group('Google Play Billing & Subscription Tests', () {
    test('Catálogo de productos expone precios y metadatos dinámicos', () async {
      final products = await adapter.getAvailableProducts();
      expect(products, isNotEmpty);
      expect(products.first.productId, equals('nano_pro_monthly'));
      expect(products.first.formattedPrice, contains('\$'));
      expect(products.first.tier, equals(SubscriptionTier.pro));
    });

    test('Plan inicial es Free por defecto', () {
      expect(controller.state.plan.tier, equals(SubscriptionTier.free));
      expect(controller.state.plan.isProOrHigher, isFalse);
    });

    test('Compra exitosa actualiza el plan y otorga entitlements Pro', () async {
      final success = await controller.purchase('nano_pro_monthly');
      expect(success, isTrue);
      expect(controller.state.plan.tier, equals(SubscriptionTier.pro));
      expect(controller.state.plan.isProOrHigher, isTrue);
      expect(
        controller.state.plan.entitlements,
        contains('pro_automation_engine'),
      );
    });

    test('Restaurar compras cuando existe plan Pro activo devuelve Pro', () async {
      await controller.purchase('nano_pro_monthly');
      await controller.restore();
      expect(controller.state.plan.isProOrHigher, isTrue);
      expect(controller.state.successMessage, contains('✓ Compras restauradas'));
    });

    test('Restaurar compras en cuenta sin compras informa estado', () async {
      final freshAdapter = GooglePlayBillingAdapter();
      final freshController = SubscriptionController(freshAdapter);
      await freshController.restore();
      expect(freshController.state.plan.tier, equals(SubscriptionTier.free));
      expect(freshController.state.errorMessage, contains('No encontramos una suscripción'));
      freshController.dispose();
    });
  });
}
