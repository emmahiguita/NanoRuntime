import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser/domain/browser_site_profile.dart';
import 'package:nanoai/features/browser/infrastructure/browser_zoom_scripts.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_web_identity_coordinator.dart';

void main() {
  group('BrowserSiteProfile', () {
    test('TikTok diferencia móvil y escritorio adaptativo', () {
      for (final url in <String>[
        'https://www.tiktok.com/',
        'https://m.tiktok.com/v/123',
        'https://app-va.tiktokv.com/redirect/',
        'https://sf16-website-login.neutral.ttwstatic.com/',
      ]) {
        expect(BrowserSiteProfile.isTikTokWebUrl(url), isTrue);
        expect(BrowserSiteProfile.requiresMobileIdentity(url), isTrue);
        expect(
          BrowserSiteProfile.requiresMobileIdentity(url, userDesktopMode: true),
          isFalse,
        );
        expect(
          BrowserSiteProfile.usesDesktop(url: url, userDesktopMode: true),
          isTrue,
        );
        expect(
          BrowserSiteProfile.usesAdaptiveDesktop(
            url: url,
            userDesktopMode: true,
          ),
          isTrue,
        );
        expect(BrowserSiteProfile.usesDeviceWidthLayout(url), isTrue);
      }
    });

    test('WhatsApp Web conserva su requisito desktop', () {
      expect(
        BrowserSiteProfile.usesDesktop(
          url: 'https://web.whatsapp.com/',
          userDesktopMode: false,
        ),
        isTrue,
      );
    });

    test('no confunde dominios parecidos con TikTok', () {
      expect(
        BrowserSiteProfile.requiresMobileIdentity(
          'https://tiktok.com.example.org/',
        ),
        isFalse,
      );
    });

    test('prepara TikTok antes de su primera petición HTTP', () {
      final identity = BrowserWebIdentityCoordinator(
        isAlive: () => true,
        userDesktopMode: () => true,
      );

      expect(
        identity.mustPrepareInitial(
          'https://www.tiktok.com/foryou',
          initialized: false,
        ),
        isTrue,
      );
      expect(identity.usesDesktop('https://www.tiktok.com/foryou'), isTrue);
      expect(
        identity.usesAdaptiveDesktop('https://www.tiktok.com/foryou'),
        isTrue,
      );
      expect(
        identity.mustPrepareInitial(
          'https://www.tiktok.com/foryou',
          initialized: true,
        ),
        isFalse,
      );
    });

    test(
      'viewport móvil se reaplica cuando el documento termina de cargar',
      () {
        expect(
          BrowserZoomScripts.mobileViewportAdapterScript,
          contains('width=device-width'),
        );
        expect(
          BrowserZoomScripts.mobileViewportAdapterScript,
          contains('DOMContentLoaded'),
        );
        expect(
          BrowserZoomScripts.mobileViewportAdapterScript,
          contains('viewport-fit=cover'),
        );
      },
    );

    test('desktop adaptativo usa viewport real y no canvas de 1280 px', () {
      expect(
        BrowserZoomScripts.adaptiveDesktopViewportAdapterScript,
        contains('width=device-width'),
      );
      expect(
        BrowserZoomScripts.adaptiveDesktopViewportAdapterScript,
        isNot(contains('width=1280')),
      );
    });
  });
}
