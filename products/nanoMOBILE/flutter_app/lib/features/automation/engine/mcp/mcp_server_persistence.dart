/// Persistence for user-configured Automation MCP servers.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mcp_client_port.dart';

abstract interface class McpCredentialStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

final class FlutterSecureMcpCredentialStore implements McpCredentialStore {
  FlutterSecureMcpCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class McpPersistedServerConfiguration {
  const McpPersistedServerConfiguration({
    required this.descriptor,
    required this.credentialToken,
    this.missingCredential = false,
  });

  final McpServerDescriptor descriptor;
  final String? credentialToken;
  final bool missingCredential;
}

/// Keeps endpoint metadata in preferences and auth material in secure storage.
final class McpServerPersistence {
  McpServerPersistence({
    required McpCredentialStore credentials,
    SharedPreferences? preferences,
  }) : _credentials = credentials,
       _preferences = preferences;

  static const String _preferenceKey = 'nano_automation_mcp_servers_v1';
  static const String _credentialPrefix = 'nano.automation.mcp.credential.v1.';

  final McpCredentialStore _credentials;
  final SharedPreferences? _preferences;

  String credentialRefFor(String serverId) => '$_credentialPrefix$serverId';

  Future<SharedPreferences> _prefs() async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<void> save(
    McpServerDescriptor descriptor, {
    String? credentialToken,
  }) async {
    validateDescriptor(descriptor);
    final reference = credentialRefFor(descriptor.id);
    final token = credentialToken?.trim();
    final previousToken = await _credentials.read(reference);
    final prefs = await _prefs();
    final records = _readRecords(prefs.getString(_preferenceKey));

    try {
      if (token == null || token.isEmpty) {
        await _credentials.delete(reference);
      } else {
        await _credentials.write(reference, token);
      }

      records[descriptor.id] = {
        'id': descriptor.id,
        'displayName': descriptor.displayName,
        'transport': descriptor.transport.name,
        'endpoint': descriptor.endpoint,
        'credentialRef': reference,
        'requiresCredential': token?.isNotEmpty == true,
        'metadata': descriptor.metadata,
      };
      await prefs.setString(_preferenceKey, jsonEncode(records));
    } catch (_) {
      if (previousToken == null) {
        await _credentials.delete(reference);
      } else {
        await _credentials.write(reference, previousToken);
      }
      rethrow;
    }
  }

  Future<List<McpPersistedServerConfiguration>> load() async {
    final prefs = await _prefs();
    final records = _readRecords(prefs.getString(_preferenceKey));
    final loaded = <McpPersistedServerConfiguration>[];

    for (final entry in records.entries) {
      final record = entry.value;
      try {
        final id = record['id'] as String;
        final name = record['displayName'] as String;
        final endpoint = record['endpoint'] as String;
        final reference = record['credentialRef'] as String;
        if (id != entry.key || reference != credentialRefFor(id)) continue;
        final descriptor = McpServerDescriptor(
          id: id,
          displayName: name,
          transport: McpTransportKind.streamableHttp,
          endpoint: endpoint,
          credentialRef: reference,
          metadata: _metadataFrom(record['metadata']),
        );
        validateDescriptor(descriptor);
        final token = await _credentials.read(reference);
        final missing = record['requiresCredential'] == true && token == null;
        loaded.add(
          McpPersistedServerConfiguration(
            descriptor: descriptor,
            credentialToken: token,
            missingCredential: missing,
          ),
        );
      } catch (_) {
        // Ignore one malformed entry while preserving the other connections.
      }
    }
    return List.unmodifiable(loaded);
  }

  Future<void> remove(String serverId) async {
    final prefs = await _prefs();
    final records = _readRecords(prefs.getString(_preferenceKey))
      ..remove(serverId);
    if (records.isEmpty) {
      await prefs.remove(_preferenceKey);
    } else {
      await prefs.setString(_preferenceKey, jsonEncode(records));
    }
    await _credentials.delete(credentialRefFor(serverId));
  }

  void validateDescriptor(McpServerDescriptor descriptor) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(descriptor.id)) {
      throw const FormatException('invalid_mcp_server_id');
    }
    if (descriptor.transport != McpTransportKind.streamableHttp) {
      throw const FormatException('unsupported_persisted_mcp_transport');
    }
    if (const {'device', 'nano.mobile', 'nano-linux'}.contains(descriptor.id)) {
      throw const FormatException('reserved_mcp_server_id');
    }
    final endpoint = Uri.tryParse(descriptor.endpoint?.trim() ?? '');
    if (endpoint == null ||
        !{'http', 'https'}.contains(endpoint.scheme) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.fragment.isNotEmpty ||
        endpoint.queryParameters.keys.any(
          (key) => RegExp(
            r'token|key|auth|secret|credential',
            caseSensitive: false,
          ).hasMatch(key),
        )) {
      throw const FormatException('unsafe_or_invalid_mcp_endpoint');
    }
  }

  Map<String, Map<String, dynamic>> _readRecords(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: Map<String, dynamic>.from(entry.value as Map),
      };
    } on FormatException {
      return {};
    }
  }

  Map<String, Object?> _metadataFrom(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
}
