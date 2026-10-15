import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser/domain/browser_navigation_policy.dart';
import 'package:nanoai/features/browser/infrastructure/browser_security_firewall.dart';

void main() {
  group('BrowserNavigationPolicy', () {
    test('clasifica esquemas web normales (http / https)', () {
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('https://www.tiktok.com/@creator/video/123')),
        equals(NavigationTargetType.web),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('http://example.com/index.html')),
        equals(NavigationTargetType.web),
      );
    });

    test('clasifica recursos web internos (about, blob, data)', () {
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('about:blank')),
        equals(NavigationTargetType.internalWeb),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('blob:https://www.tiktok.com/1234-abcd')),
        equals(NavigationTargetType.internalWeb),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('data:image/png;base64,iVBORw0KGgo=')),
        equals(NavigationTargetType.internalWeb),
      );
    });

    test('clasifica handlers de comunicación específicos (tel, mailto, market)', () {
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('tel:+573001234567')),
        equals(NavigationTargetType.phone),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('sms:+573001234567')),
        equals(NavigationTargetType.phone),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('mailto:support@nanoai.dev')),
        equals(NavigationTargetType.email),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('market://details?id=com.zhiliaoapp.musically')),
        equals(NavigationTargetType.store),
      );
    });

    test('clasifica deep links de aplicaciones externas incluyendo snssdk1340 de TikTok', () {
      expect(
        BrowserNavigationPolicy.classifyUri(
          Uri.parse('snssdk1340://aweme/detail/7695306632284228885?utm_source=tiktokweb'),
        ),
        equals(NavigationTargetType.externalApp),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('snssdk1180://aweme/detail/123')),
        equals(NavigationTargetType.externalApp),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('whatsapp://send?phone=123')),
        equals(NavigationTargetType.externalApp),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('intent://scan/#Intent;scheme=zxing;package=com.google.zxing.client.android;end')),
        equals(NavigationTargetType.externalApp),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('customapp://action/view')),
        equals(NavigationTargetType.externalApp),
      );
    });

    test('clasifica esquemas prohibidos e inválidos como unsupported', () {
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('file:///etc/passwd')),
        equals(NavigationTargetType.unsupported),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('chrome://settings')),
        equals(NavigationTargetType.unsupported),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('javascript:alert(1)')),
        equals(NavigationTargetType.unsupported),
      );
      expect(
        BrowserNavigationPolicy.classifyUri(Uri.parse('content://contacts/people')),
        equals(NavigationTargetType.unsupported),
      );
    });

    test('identifica esquemas y dominios legítimos de TikTok', () {
      expect(BrowserNavigationPolicy.isTikTokScheme('snssdk1340'), isTrue);
      expect(BrowserNavigationPolicy.isTikTokScheme('snssdk1180'), isTrue);
      expect(BrowserNavigationPolicy.isTikTokScheme('snssdk1233'), isTrue);
      expect(BrowserNavigationPolicy.isTikTokScheme('tiktok'), isTrue);
      expect(BrowserNavigationPolicy.isTikTokScheme('whatsapp'), isFalse);

      expect(BrowserNavigationPolicy.isTikTokOrigin('https://www.tiktok.com'), isTrue);
      expect(BrowserNavigationPolicy.isTikTokOrigin('https://m.tiktok.com/@user'), isTrue);
      expect(BrowserNavigationPolicy.isTikTokOrigin('https://v.tiktok.com'), isTrue);
      expect(BrowserNavigationPolicy.isTikTokOrigin('https://phishing-site.example'), isFalse);
    });

    test('valida afinidad de esquema con origen web emisor', () {
      expect(
        BrowserNavigationPolicy.isTrustedSchemeForOrigin(
          scheme: 'snssdk1340',
          origin: 'https://www.tiktok.com',
        ),
        isTrue,
      );
      expect(
        BrowserNavigationPolicy.isTrustedSchemeForOrigin(
          scheme: 'snssdk1340',
          origin: 'https://sitio-malicioso.example',
        ),
        isFalse,
      );
      expect(
        BrowserNavigationPolicy.isTrustedSchemeForOrigin(
          scheme: 'whatsapp',
          origin: 'https://api.whatsapp.com',
        ),
        isTrue,
      );
    });

    test('extractOrigin limpia parámetros sensibles, tokens y query strings', () {
      final uri = Uri.parse(
        'https://www.tiktok.com/@daniela/video/123456?token=secret123&utm_source=tiktokweb&referer=test',
      );
      final origin = BrowserNavigationPolicy.extractOrigin(uri);
      expect(origin, equals('https://www.tiktok.com'));
      expect(origin, isNot(contains('token')));
      expect(origin, isNot(contains('secret123')));
      expect(origin, isNot(contains('utm_source')));

      final privateUri = Uri.parse('http://192.168.1.50:8080/admin?key=supersecret');
      final privateOrigin = BrowserNavigationPolicy.extractOrigin(privateUri);
      expect(privateOrigin, equals('http://192.168.1.50:8080'));
      expect(privateOrigin, isNot(contains('key')));
      expect(privateOrigin, isNot(contains('supersecret')));
    });
  });

  group('BrowserSecurityFirewall semantic codes and classification', () {
    test('clasifica snssdk1340 como EXTERNAL_APP_REQUEST y NO como red privada o puerto interno', () {
      final evaluation = BrowserSecurityFirewall.evaluateUrl(
        'snssdk1340://aweme/detail/7695306632284228885?utm_source=tiktokweb',
      );

      expect(evaluation.code, equals(FirewallSecurityCode.externalAppRequest));
      expect(evaluation.isAllowed, isFalse);
      expect(evaluation.code.code, equals('EXTERNAL_APP_REQUEST'));
      expect(evaluation.code, isNot(equals(FirewallSecurityCode.privateNetworkBlocked)));
      expect(evaluation.code, isNot(equals(FirewallSecurityCode.loopbackBlocked)));
      expect(evaluation.code, isNot(equals(FirewallSecurityCode.unsafePortBlocked)));
      expect(evaluation.reason, contains('aplicación externa'));
    });

    test('mantiene bloqueo estricto de loopback con código LOOPBACK_BLOCKED', () {
      final eval1 = BrowserSecurityFirewall.evaluateUrl('http://localhost');
      expect(eval1.code, equals(FirewallSecurityCode.loopbackBlocked));
      expect(eval1.code.code, equals('LOOPBACK_BLOCKED'));
      expect(eval1.isAllowed, isFalse);

      final eval2 = BrowserSecurityFirewall.evaluateUrl('http://127.0.0.1:3000');
      expect(eval2.code, equals(FirewallSecurityCode.loopbackBlocked));
      expect(eval2.isAllowed, isFalse);

      final eval3 = BrowserSecurityFirewall.evaluateUrl('http://[::1]');
      expect(eval3.code, equals(FirewallSecurityCode.loopbackBlocked));
      expect(eval3.isAllowed, isFalse);
    });

    test('mantiene bloqueo estricto de redes privadas con código PRIVATE_NETWORK_BLOCKED', () {
      final eval1 = BrowserSecurityFirewall.evaluateUrl('http://192.168.1.1');
      expect(eval1.code, equals(FirewallSecurityCode.privateNetworkBlocked));
      expect(eval1.code.code, equals('PRIVATE_NETWORK_BLOCKED'));
      expect(eval1.isAllowed, isFalse);

      final eval2 = BrowserSecurityFirewall.evaluateUrl('http://10.0.0.1');
      expect(eval2.code, equals(FirewallSecurityCode.privateNetworkBlocked));
      expect(eval2.isAllowed, isFalse);

      final eval3 = BrowserSecurityFirewall.evaluateUrl('http://172.16.0.1');
      expect(eval3.code, equals(FirewallSecurityCode.privateNetworkBlocked));
      expect(eval3.isAllowed, isFalse);

      final eval4 = BrowserSecurityFirewall.evaluateUrl('http://169.254.169.254/latest/meta-data');
      expect(eval4.code, equals(FirewallSecurityCode.privateNetworkBlocked));
      expect(eval4.isAllowed, isFalse);
    });

    test('mantiene bloqueo de puertos internos con código UNSAFE_PORT_BLOCKED', () {
      final eval1 = BrowserSecurityFirewall.evaluateUrl('http://example.com:8080');
      expect(eval1.code, equals(FirewallSecurityCode.unsafePortBlocked));
      expect(eval1.code.code, equals('UNSAFE_PORT_BLOCKED'));
      expect(eval1.isAllowed, isFalse);

      final eval2 = BrowserSecurityFirewall.evaluateUrl('http://example.com:22');
      expect(eval2.code, equals(FirewallSecurityCode.unsafePortBlocked));
      expect(eval2.isAllowed, isFalse);
    });

    test('permite navegación web legítima con código ALLOWED', () {
      final eval = BrowserSecurityFirewall.evaluateUrl('https://www.tiktok.com/@daniela/video/123');
      expect(eval.code, equals(FirewallSecurityCode.allowed));
      expect(eval.code.code, equals('ALLOWED'));
      expect(eval.isAllowed, isTrue);
    });

    test('reconoce hosts de proveedores OAuth federados', () {
      expect(
        BrowserNavigationPolicy.isOAuthProviderHost('accounts.google.com'),
        isTrue,
      );
      expect(
        BrowserNavigationPolicy.isOAuthProviderHost('accounts.google.com.mx'),
        isTrue,
      );
      expect(
        BrowserNavigationPolicy.isOAuthProviderHost('appleid.apple.com'),
        isTrue,
      );
      expect(
        BrowserNavigationPolicy.isOAuthProviderHost('github.com'),
        isTrue,
      );
      expect(
        BrowserNavigationPolicy.isOAuthProviderHost('login.microsoftonline.com'),
        isTrue,
      );
      // Subdominios legítimos
      expect(
        BrowserNavigationPolicy.isOAuthProviderHost('sub.github.com'),
        isTrue,
      );
      // Falsificaciones y hosts no federados
      expect(
        BrowserNavigationPolicy.isOAuthProviderHost('accounts.google.com.evil.com'),
        isFalse,
      );
      expect(
        BrowserNavigationPolicy.isOAuthProviderHost('google.com'),
        isFalse,
      );
      expect(
        BrowserNavigationPolicy.isOAuthProviderHost('tiktok.com'),
        isFalse,
      );
    });
  });
}
