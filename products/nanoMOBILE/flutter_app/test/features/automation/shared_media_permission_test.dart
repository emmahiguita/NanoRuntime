import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nanoai/core/services/shared_gemini_media_reader.dart';
import 'package:nanoai/core/services/api_provider_service.dart';
import 'package:nanoai/features/automation/data/media/attachment_content_reader.dart';
import 'package:nanoai/features/automation/domain/incoming_attachment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'Sin autorización o con modo local no consulta ni sube archivos',
    () async {
      var requests = 0;
      final reader = SharedGeminiMediaReader(
        cloudAllowed: () async => false,
        client: () => MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      expect(
        await reader.read(File('missing'), 'image/png', allowed: false),
        isNull,
      );
      expect(
        await reader.read(File('missing'), 'image/png', allowed: true),
        isNull,
      );
      expect(requests, 0);
    },
  );

  test(
    'Usa clave y modelo canónicos; transmite MIME y bytes reales sin pensamientos internos',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'nano-cloud-media-test-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final file = await File(
        '${folder.path}/sample.png',
      ).writeAsBytes([1, 2, 3]);
      final store = ApiProviderSettingsStore();
      await store.save(
        const ApiProviderConfig(
          provider: ApiProviderKind.gemini,
          model: 'configured-model',
          baseUrl: 'https://example.org/v1beta',
          hasApiKey: true,
        ),
        apiKey: 'test-only',
      );
      var requests = 0;
      final reader = SharedGeminiMediaReader(
        store: store,
        cloudAllowed: () async => true,
        client: () => MockClient((request) async {
          requests++;
          expect(
            request.url.path,
            '/v1beta/models/configured-model:generateContent',
          );
          expect(request.headers['x-goog-api-key'], 'test-only');
          final body = jsonDecode(request.body) as Map;
          final data =
              (((body['contents'] as List).first as Map)['parts'] as List).first
                  as Map;
          expect(data['inlineData'], {
            'mimeType': 'image/png',
            'data': base64Encode([1, 2, 3]),
          });
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'thought': true, 'text': 'No mostrar'},
                      {'text': 'Objeto rojo'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      expect(
        await reader.read(file, 'image/png', allowed: true),
        'Objeto rojo',
      );
      expect(requests, 1);
      expect(
        (await store.loadForProvider(ApiProviderKind.gemini)).model,
        'configured-model',
      );
    },
  );

  test(
    'OCR local se conserva; escena necesita autorización explícita',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'nano-image-permission-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final file = await File('${folder.path}/sample.png').writeAsBytes([1]);
      final attachment = IncomingAttachment(
        type: AttachmentType.image,
        localPath: file.path,
        mimeType: 'image/png',
        observedAt: 1,
        confidence: AttachmentConfidence.resolvedExact,
      );
      var remote = 0;
      final reader = AttachmentContentReader(
        document: (_, {required image}) async => {'text': 'TOTAL 25'},
        cloud: (_, __, {required allowed}) async {
          remote++;
          return 'Objeto rojo';
        },
      );
      expect(
        (await reader.read(attachment, detailedVisual: true)).text,
        contains('TOTAL 25'),
      );
      expect(remote, 0);
      expect(
        (await reader.read(
          attachment,
          detailedVisual: true,
          allowCloud: true,
        )).text,
        contains('Objeto rojo'),
      );
      expect(remote, 1);
    },
  );
}
