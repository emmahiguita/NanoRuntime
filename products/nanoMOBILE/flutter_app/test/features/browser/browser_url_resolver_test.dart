import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/browser/domain/browser_url_resolver.dart';

void main() {
  group('BrowserUrlResolver', () {
    test('resuelve entrada vacía a la página principal por defecto', () {
      expect(BrowserUrlResolver.resolveUrl(''), equals('https://www.google.com'));
      expect(BrowserUrlResolver.resolveUrl('   '), equals('https://www.google.com'));
    });

    test('preserva esquemas conocidos http, https, file, about', () {
      expect(
        BrowserUrlResolver.resolveUrl('http://example.com'),
        equals('http://example.com'),
      );
      expect(
        BrowserUrlResolver.resolveUrl('https://chatgpt.com'),
        equals('https://chatgpt.com'),
      );
      expect(
        BrowserUrlResolver.resolveUrl('about:blank'),
        equals('about:blank'),
      );
    });

    test('antepone https a dominios sin esquema', () {
      expect(
        BrowserUrlResolver.resolveUrl('google.com'),
        equals('https://google.com'),
      );
      expect(
        BrowserUrlResolver.resolveUrl('github.com/flutter/flutter'),
        equals('https://github.com/flutter/flutter'),
      );
      expect(
        BrowserUrlResolver.resolveUrl('deepseek.com'),
        equals('https://deepseek.com'),
      );
    });

    test('antepone http a IPs y localhost', () {
      expect(
        BrowserUrlResolver.resolveUrl('localhost:8080'),
        equals('http://localhost:8080'),
      );
      expect(
        BrowserUrlResolver.resolveUrl('192.168.1.1'),
        equals('http://192.168.1.1'),
      );
    });

    test('convierte términos de búsqueda a consultas de Google', () {
      expect(
        BrowserUrlResolver.resolveUrl('cómo instalar flutter en ubuntu'),
        equals('https://www.google.com/search?q=c%C3%B3mo%20instalar%20flutter%20en%20ubuntu'),
      );
      expect(
        BrowserUrlResolver.resolveUrl('noticias del día'),
        equals('https://www.google.com/search?q=noticias%20del%20d%C3%ADa'),
      );
    });

    test('extractHost devuelve el dominio sin www', () {
      expect(BrowserUrlResolver.extractHost('https://www.google.com/search?q=test'), equals('google.com'));
      expect(BrowserUrlResolver.extractHost('https://github.com/repo'), equals('github.com'));
    });

    test('isSecure identifica correctamente HTTPS', () {
      expect(BrowserUrlResolver.isSecure('https://secure.site.org'), isTrue);
      expect(BrowserUrlResolver.isSecure('http://insecure.site.org'), isFalse);
    });
  });
}
