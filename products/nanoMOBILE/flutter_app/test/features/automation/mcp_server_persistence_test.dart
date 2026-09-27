import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_client_port.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_http_diagnostics.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_server_persistence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('McpServerPersistence', () {
    late FakeMcpCredentialStore credentials;
    late McpServerPersistence persistence;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      credentials = FakeMcpCredentialStore();
      persistence = McpServerPersistence(credentials: credentials);
    });

    test('restores endpoint and secret separately after restart', () async {
      const secret = 'Bearer private-test-token';
      final descriptor = _descriptor(persistence);

      await persistence.save(descriptor, credentialToken: secret);

      final preferences = await SharedPreferences.getInstance();
      final rawPreferences = preferences.getString(
        'nano_automation_mcp_servers_v1',
      )!;
      expect(rawPreferences, contains('https://mcp.example.test/mcp'));
      expect(rawPreferences, isNot(contains(secret)));
      expect(
        rawPreferences,
        contains(persistence.credentialRefFor(descriptor.id)),
      );

      final restored = await persistence.load();
      expect(restored, hasLength(1));
      expect(restored.single.descriptor.endpoint, descriptor.endpoint);
      expect(restored.single.descriptor.credentialRef, isNot(secret));
      expect(restored.single.credentialToken, secret);
      expect(restored.single.missingCredential, isFalse);

      final headers = mcpHttpHeaders(
        restored.single.descriptor,
        credentialToken: restored.single.credentialToken,
      );
      expect(headers['Authorization'], secret);
      expect(
        mcpHttpHeaders(restored.single.descriptor)['Authorization'],
        isNull,
      );
    });

    test(
      'reports a missing secure credential and never persists its value',
      () async {
        final descriptor = _descriptor(persistence);
        await persistence.save(descriptor, credentialToken: 'secret-to-delete');
        await credentials.delete(persistence.credentialRefFor(descriptor.id));

        final restored = await persistence.load();

        expect(restored.single.missingCredential, isTrue);
        expect(restored.single.credentialToken, isNull);
      },
    );

    test('remove deletes endpoint metadata and secure credential', () async {
      final descriptor = _descriptor(persistence);
      final reference = persistence.credentialRefFor(descriptor.id);
      await persistence.save(descriptor, credentialToken: 'remove-me');

      await persistence.remove(descriptor.id);

      expect(await persistence.load(), isEmpty);
      expect(credentials.values, isNot(contains(reference)));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('nano_automation_mcp_servers_v1'), isNull);
    });

    test('rejects credentials embedded in endpoint query parameters', () async {
      const descriptor = McpServerDescriptor(
        id: 'mcp-test',
        displayName: 'Test MCP',
        transport: McpTransportKind.streamableHttp,
        endpoint: 'https://mcp.example.test/mcp?api_key=hidden',
      );

      await expectLater(
        persistence.save(descriptor, credentialToken: 'secret'),
        throwsFormatException,
      );
    });
  });
}

McpServerDescriptor _descriptor(McpServerPersistence persistence) =>
    McpServerDescriptor(
      id: 'mcp-test',
      displayName: 'Test MCP',
      transport: McpTransportKind.streamableHttp,
      endpoint: 'https://mcp.example.test/mcp',
      credentialRef: persistence.credentialRefFor('mcp-test'),
    );

final class FakeMcpCredentialStore implements McpCredentialStore {
  final Map<String, String> _values = {};

  Iterable<String> get values => _values.keys;

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
