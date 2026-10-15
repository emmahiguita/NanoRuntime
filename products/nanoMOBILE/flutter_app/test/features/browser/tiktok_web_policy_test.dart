import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser/domain/tiktok_web_policy.dart';

void main() {
  group('TikTokWebPolicy — origen', () {
    test('reconoce tiktok.com y subdominios legítimos', () {
      expect(TikTokWebPolicy.isTikTokOrigin(Uri.parse('https://tiktok.com')), isTrue);
      expect(TikTokWebPolicy.isTikTokOrigin(Uri.parse('https://www.tiktok.com')), isTrue);
      expect(TikTokWebPolicy.isTikTokOrigin(Uri.parse('https://m.tiktok.com')), isTrue);
      expect(
        TikTokWebPolicy.isTikTokOrigin(Uri.parse('https://sub.tiktok.com/x')),
        isTrue,
      );
    });

    test('rechaza falsificaciones y orígenes ajenos', () {
      expect(
        TikTokWebPolicy.isTikTokOrigin(Uri.parse('https://tiktok.com.evil.com')),
        isFalse,
      );
      expect(
        TikTokWebPolicy.isTikTokOrigin(Uri.parse('https://evil-tiktok.com')),
        isFalse,
      );
      expect(TikTokWebPolicy.isTikTokOrigin(null), isFalse);
    });
  });

  group('TikTokWebPolicy — esquemas de app', () {
    test('detecta deep links de la app TikTok', () {
      expect(
        TikTokWebPolicy.isTikTokAppScheme(Uri.parse('snssdk1340://aweme/detail/1')),
        isTrue,
      );
      expect(TikTokWebPolicy.isTikTokAppScheme(Uri.parse('snssdk1180://x')), isTrue);
      expect(TikTokWebPolicy.isTikTokAppScheme(Uri.parse('tiktok://home')), isTrue);
      expect(
        TikTokWebPolicy.isTikTokAppScheme(Uri.parse('musically://x')),
        isTrue,
      );
    });

    test('no confunde web, intent ni otras apps', () {
      expect(
        TikTokWebPolicy.isTikTokAppScheme(Uri.parse('https://www.tiktok.com')),
        isFalse,
      );
      expect(
        TikTokWebPolicy.isTikTokAppScheme(Uri.parse('whatsapp://send?text=x')),
        isFalse,
      );
      expect(
        TikTokWebPolicy.isTikTokAppScheme(Uri.parse('intent://x#Intent;end')),
        isFalse,
      );
    });
  });

  group('TikTokWebPolicy — intent://', () {
    const realIntent =
        'intent://aweme/detail/123#Intent;scheme=snssdk1233;'
        'package=com.zhiliaoapp.musically;'
        'S.browser_fallback_url=https%3A%2F%2Fwww.tiktok.com%2F%40user%2Fvideo%2F123;end';

    test('identifica intents dirigidos a TikTok', () {
      expect(TikTokWebPolicy.isTikTokIntent(Uri.parse(realIntent)), isTrue);
      expect(
        TikTokWebPolicy.isTikTokIntent(
          Uri.parse('intent://scan/#Intent;scheme=zxing;package=com.example;end'),
        ),
        isFalse,
      );
      expect(
        TikTokWebPolicy.isTikTokIntent(Uri.parse('https://www.tiktok.com')),
        isFalse,
      );
    });

    test('extrae el fallback web seguro del intent', () {
      final fallback = TikTokWebPolicy.extractIntentWebFallback(
        Uri.parse(realIntent),
      );
      expect(fallback, isNotNull);
      expect(fallback!.scheme, 'https');
      expect(fallback.host, 'www.tiktok.com');
    });

    test('rechaza fallback inexistente o peligroso', () {
      expect(
        TikTokWebPolicy.extractIntentWebFallback(
          Uri.parse('intent://x#Intent;scheme=snssdk1233;end'),
        ),
        isNull,
      );
      expect(
        TikTokWebPolicy.extractIntentWebFallback(
          Uri.parse(
            'intent://x#Intent;scheme=snssdk1233;'
            'S.browser_fallback_url=javascript%3Aalert(1);end',
          ),
        ),
        isNull,
      );
      expect(
        TikTokWebPolicy.extractIntentWebFallback(
          Uri.parse('https://www.tiktok.com'),
        ),
        isNull,
      );
    });
  });

  group('TikTokWebPolicy — decisión por modo', () {
    final scheme = Uri.parse('snssdk1340://aweme/detail/1');

    test('STAY_IN_WEB nunca abre la app, con o sin gesto', () {
      expect(
        TikTokWebPolicy.decideAppScheme(
          uri: scheme,
          hasGesture: true,
          behavior: ExternalAppBehavior.stayInWeb,
        ),
        TikTokNavigationDecision.stayInWeb,
      );
      expect(
        TikTokWebPolicy.decideAppScheme(
          uri: scheme,
          hasGesture: false,
          behavior: ExternalAppBehavior.stayInWeb,
        ),
        TikTokNavigationDecision.stayInWeb,
      );
    });

    test('ASK pregunta solo con gesto explícito', () {
      expect(
        TikTokWebPolicy.decideAppScheme(
          uri: scheme,
          hasGesture: true,
          behavior: ExternalAppBehavior.ask,
        ),
        TikTokNavigationDecision.askUser,
      );
      expect(
        TikTokWebPolicy.decideAppScheme(
          uri: scheme,
          hasGesture: false,
          behavior: ExternalAppBehavior.ask,
        ),
        TikTokNavigationDecision.stayInWeb,
      );
    });

    test('ALLOW_EXPLICIT lanza solo con gesto explícito', () {
      expect(
        TikTokWebPolicy.decideAppScheme(
          uri: scheme,
          hasGesture: true,
          behavior: ExternalAppBehavior.allowExplicit,
        ),
        TikTokNavigationDecision.openExternalExplicitly,
      );
      expect(
        TikTokWebPolicy.decideAppScheme(
          uri: scheme,
          hasGesture: false,
          behavior: ExternalAppBehavior.allowExplicit,
        ),
        TikTokNavigationDecision.stayInWeb,
      );
    });

    test('esquema no-TikTok no entra en la política', () {
      expect(
        TikTokWebPolicy.decideAppScheme(
          uri: Uri.parse('whatsapp://send?text=x'),
          hasGesture: true,
          behavior: ExternalAppBehavior.allowExplicit,
        ),
        TikTokNavigationDecision.stayInWeb,
      );
    });

    test('fromId restaura el modo guardado con default seguro', () {
      expect(
        ExternalAppBehavior.fromId('ALLOW_EXPLICIT'),
        ExternalAppBehavior.allowExplicit,
      );
      expect(
        ExternalAppBehavior.fromId(null),
        ExternalAppBehavior.stayInWeb,
      );
      expect(
        ExternalAppBehavior.fromId('desconocido'),
        ExternalAppBehavior.stayInWeb,
      );
    });
  });

  group('TikTokWebPolicy — dominios HTTPS de TikTok no son deep links', () {
    test('tiktokv.com por https es tráfico web normal', () {
      final media = Uri.parse(
        'https://app-va.tiktokv.com/redirect/?redirect_url=xyz',
      );
      expect(TikTokWebPolicy.isTikTokAppScheme(media), isFalse);
      expect(TikTokWebPolicy.isTikTokIntent(media), isFalse);
    });

    test('otras CDN https de TikTok tampoco son deep links', () {
      for (final url in const [
        'https://sf16-website-login.neutral.ttwstatic.com/obj/app.js',
        'https://v16-webapp.tiktok.com/video.mp4',
        'https://p16-sign.tiktokcdn.com/img.jpeg',
      ]) {
        final uri = Uri.parse(url);
        expect(TikTokWebPolicy.isTikTokAppScheme(uri), isFalse, reason: url);
        expect(TikTokWebPolicy.isTikTokIntent(uri), isFalse, reason: url);
      }
    });
  });
}
