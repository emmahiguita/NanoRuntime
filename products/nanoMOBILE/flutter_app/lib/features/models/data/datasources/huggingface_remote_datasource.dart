/// Implementación de la fuente de datos remota para HuggingFace Hub (SRP & DIP).
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'i_model_metadata_datasource.dart';

class HuggingFaceRemoteDataSource implements IModelRemoteMetadataDataSource {
  final http.Client _client;
  static const Duration _defaultTimeout = Duration(seconds: 4);

  HuggingFaceRemoteDataSource({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<RemoteModelMetadataDto?> fetchModelMetadata(String repoId) async {
    try {
      final uri = Uri.https('huggingface.co', '/api/models/$repoId');
      final response = await _client.get(uri).timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return RemoteModelMetadataDto.fromJson(json);
      }
    } catch (e) {
      if (kDebugMode) {
        print('HuggingFaceRemoteDataSource error para $repoId: $e');
      }
    }
    return null;
  }
}
