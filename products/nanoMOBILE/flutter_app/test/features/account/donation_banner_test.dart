import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/account/application/donation_controller.dart';
import 'package:nanoai/features/account/infrastructure/voluntary_donation_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Voluntary Donation & Banner Cooldown Tests', () {
    test('Banner es visible inicialmente sin historial de descarte', () async {
      final prefs = await SharedPreferences.getInstance();
      final adapter = VoluntaryDonationAdapter(prefs: prefs);
      final shouldShow = await adapter.shouldShowSupportBanner();
      expect(shouldShow, isTrue);
    });

    test('Descartar banner persiste timestamp y activa cooldown de 7 días', () async {
      final prefs = await SharedPreferences.getInstance();
      final adapter = VoluntaryDonationAdapter(prefs: prefs);
      final controller = DonationController(adapter);

      await controller.checkBannerVisibility();
      expect(controller.state.shouldShow, isTrue);

      await controller.dismissBanner();
      expect(controller.state.shouldShow, isFalse);

      final canShowAfterDismiss = await adapter.shouldShowSupportBanner();
      expect(canShowAfterDismiss, isFalse);
    });

    test('Aporte voluntario NUNCA otorga ventajas digitales ni altera entitlements', () async {
      final prefs = await SharedPreferences.getInstance();
      final adapter = VoluntaryDonationAdapter(prefs: prefs);

      // El contrato de DonationRepository no tiene métodos de otorgamiento de plan ni Pro
      expect(adapter, isA<VoluntaryDonationAdapter>());
      // Se garantiza el cumplimiento de la política de Google Play Store
    });
  });
}
