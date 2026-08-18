import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/models/chat_models.dart';

/// Estado de descarga real de un modelo GGUF local.
///
/// - [notInstalled]: no hay archivo GGUF en el almacenamiento de la app.
/// - [downloading]: descarga streaming en curso (con [LocalModel.progress]).
/// - [verifying]: SHA256 del archivo recién descargado en curso.
/// - [installed]: archivo presente y hash verificado.
/// - [failed]: la descarga o la verificación fallaron ([LocalModel.error]).
enum ModelDownloadState {
  notInstalled,
  downloading,
  verifying,
  installed,
  failed,
}

/// Modelo local GGUF gestionado por la app mobile.
///
/// La descarga es real: URL HuggingFace + SHA256 obligatorio. La app guarda
/// el GGUF en files/nano/models/ y lo pasa al motor nanortime con --model.
class LocalModel {
  final String id;
  final String name;
  final String params;
  final String quant;
  final double sizeGb;
  final double ramGb;
  final String fileName;
  final String description;
  final ChatTemplate template;
  /// Gate R9 — tier de rendimiento (interactive/deep/extreme). EXTREME solo
  /// con confirmación explícita del usuario en la UI.
  final ModelTier tier;
  final ModelDownloadState downloadState;
  final double progress; // 0..1 durante downloading/verifying
  final String url;
  final String sha256;
  final String? localPath; // ruta absoluta del GGUF cuando installed
  final String? error; // mensaje honesto del último fallo
  final bool active;
  final bool loading;

  const LocalModel({
    required this.id,
    required this.name,
    required this.params,
    required this.quant,
    required this.sizeGb,
    required this.ramGb,
    required this.fileName,
    required this.description,
    required this.template,
    required this.tier,
    required this.downloadState,
    required this.progress,
    required this.url,
    required this.sha256,
    this.localPath,
    this.error,
    required this.active,
    required this.loading,
  });

  bool get installed => downloadState == ModelDownloadState.installed;

  LocalModel copyWith({
    ModelDownloadState? downloadState,
    double? progress,
    String? localPath,
    String? error,
    bool clearError = false,
    bool? active,
    bool? loading,
  }) {
    return LocalModel(
      id: id,
      name: name,
      params: params,
      quant: quant,
      sizeGb: sizeGb,
      ramGb: ramGb,
      fileName: fileName,
      description: description,
      template: template,
      tier: tier,
      downloadState: downloadState ?? this.downloadState,
      progress: progress ?? this.progress,
      url: url,
      sha256: sha256,
      localPath: localPath ?? this.localPath,
      error: clearError ? null : (error ?? this.error),
      active: active ?? this.active,
      loading: loading ?? this.loading,
    );
  }
}
