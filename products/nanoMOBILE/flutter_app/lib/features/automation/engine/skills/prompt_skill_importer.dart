/// Importa un SKILL.md remoto real; no descarga ni ejecuta scripts asociados.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'prompt_skill.dart';

final class PromptSkillImporter {
  const PromptSkillImporter();

  /// Solo acepta HTTPS y un archivo Markdown acotado para mantener el importador simple y seguro.
  Future<PromptSkill> fromUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.queryParameters.keys.any(
          (key) => RegExp(
            r'token|key|auth|secret|credential',
            caseSensitive: false,
          ).hasMatch(key),
        )) {
      throw const FormatException('skill_url_must_be_https');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200 || response.bodyBytes.length > 24000) {
      throw const FormatException('skill_download_failed');
    }
    if (response.request?.url.scheme != 'https') {
      throw const FormatException('skill_redirect_must_remain_https');
    }
    final markdown = utf8.decode(response.bodyBytes, allowMalformed: false);
    return PromptSkill.parse(markdown, source: '${uri.origin}${uri.path}');
  }

  /// También permite pegar el contenido, útil para skills privadas sin exponer claves en URLs.
  PromptSkill fromText(String markdown) => PromptSkill.parse(markdown);
}
