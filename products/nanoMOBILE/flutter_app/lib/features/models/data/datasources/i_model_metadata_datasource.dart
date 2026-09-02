/// Interfaces segregadas para fuentes de datos remotas y locales de metadatos (ISP & DIP).
library;

class RemoteModelMetadataDto {
  final String id;
  final String? author;
  final String? sha;
  final DateTime? lastModified;
  final int? downloads;
  final int? likes;
  final List<String> tags;
  final String? pipelineTag;
  final Map<String, dynamic> cardData;

  const RemoteModelMetadataDto({
    required this.id,
    this.author,
    this.sha,
    this.lastModified,
    this.downloads,
    this.likes,
    this.tags = const [],
    this.pipelineTag,
    this.cardData = const {},
  });

  factory RemoteModelMetadataDto.fromJson(Map<String, dynamic> json) {
    DateTime? mod;
    if (json['lastModified'] != null) {
      try {
        mod = DateTime.parse(json['lastModified'] as String);
      } catch (_) {}
    }

    return RemoteModelMetadataDto(
      id: json['id'] as String? ?? '',
      author: json['author'] as String?,
      sha: json['sha'] as String?,
      lastModified: mod,
      downloads: json['downloads'] as int?,
      likes: json['likes'] as int?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      pipelineTag: json['pipeline_tag'] as String?,
      cardData: (json['cardData'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'sha': sha,
    'lastModified': lastModified?.toIso8601String(),
    'downloads': downloads,
    'likes': likes,
    'tags': tags,
    'pipeline_tag': pipelineTag,
    'cardData': cardData,
  };
}

/// Contrato para obtención de metadatos remotos (ISP).
abstract interface class IModelRemoteMetadataDataSource {
  Future<RemoteModelMetadataDto?> fetchModelMetadata(String repoId);
}

/// Contrato para persistencia y caché local de metadatos (ISP).
abstract interface class IModelLocalMetadataCache {
  Future<void> initialize();
  RemoteModelMetadataDto? get(String repoId);
  DateTime? getTimestamp(String repoId);
  Future<void> save(
    String repoId,
    RemoteModelMetadataDto metadata,
    DateTime timestamp,
  );
  bool isFresh(String repoId, Duration ttl);
}
