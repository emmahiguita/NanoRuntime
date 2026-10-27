import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../engine/business/business_document_library.dart';
import '../engine/business/business_facts.dart';
import '../engine/voice/execution_cancellation.dart';
import '../engine/planning/whatsapp_component_requests.dart';
import '../engine/business/catalog_pdf_generator.dart';

typedef AutomationArtifactDraft = ({String contact, File file});

typedef _ArtifactRequest = ({String kind, String? name, String contact});

/// Comparte hechos o PDF reales por una sola orden del coordinador existente.
/// Los nombres son exactos: nunca elige el primer producto o archivo parecido.
abstract final class NanoArtifactCommands {
  static const _library = BusinessDocumentLibrary();
  static const _quoted = r'"(?:\\.|[^"\\])*"';
  static final _namedPattern = RegExp(
    '^(?:comparte|compartir) el (producto|PDF|documento) '
    '($_quoted) con ($_quoted)\$',
    caseSensitive: false,
  );
  static final _catalogPattern = RegExp(
    '^(?:comparte|compartir) el cat[aá]logo PDF con ($_quoted)\$',
    caseSensitive: false,
  );

  /// Comparte los mismos patrones completos con el panel y el bridge WhatsApp.
  /// Solo preserva texto crudo para una gramática de artefacto delimitada.
  static bool supports(String goal) =>
      _namedPattern.hasMatch(goal.trim()) ||
      _catalogPattern.hasMatch(goal.trim());

  /// Reserva el borrador de artefacto antes del normalizador de mensajes de WhatsApp.
  /// Una sintaxis incompleta llega al resolver para pedir aclaración, sin enviarse.
  static bool recognizes(String goal) =>
      WhatsAppComponentRequests.isArtifact(goal);

  /// Devuelve null si no es una orden de artefacto; errores de sintaxis piden aclaración.
  /// Cancelar durante preparación impide despachar después el archivo a WhatsApp.
  static Future<String?> execute(
    String goal, {
    required Future<String> Function(String) runCommand,
    required bool Function() isCancelled,
  }) async {
    try {
      final draft = await prepare(goal, isCancelled: isCancelled);
      if (draft == null) return null;
      if (isCancelled()) throw const ExecutionCancelled();
      return runCommand(
        '@whatsapp ${jsonEncode(draft.contact)} --archivo ${draft.file.path}',
      );
    } on ExecutionCancelled {
      return '[cancelled] Acción cancelada.';
    }
  }

  /// Prepara un archivo real sin abrir WhatsApp. El llamador decide cuándo
  /// entregarlo al mismo coordinador y a sus políticas de envío.
  static Future<AutomationArtifactDraft?> prepare(
    String goal, {
    required bool Function() isCancelled,
  }) async {
    final request = _parse(goal);
    if (request == null) return null;
    if (isCancelled()) throw const ExecutionCancelled();
    final facts = await const BusinessFactsStore().load();
    if (isCancelled()) throw const ExecutionCancelled();
    final File file;
    if (request.kind == 'pdf') {
      file = await _existingPdf(facts, request.name!);
    } else {
      final selected = _selectedFacts(facts, request);
      final bytes = await CatalogPdfGenerator.generatePdfBytes(facts: selected);
      if (isCancelled()) throw const ExecutionCancelled();
      final directory = await getTemporaryDirectory();
      if (isCancelled()) throw const ExecutionCancelled();
      // Ruta única: otro catálogo abierto no puede sobrescribir el PDF del turno.
      file = File(
        '${directory.path}/nano_${request.kind}_'
        '${DateTime.now().microsecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
    }
    if (isCancelled()) throw const ExecutionCancelled();
    if (!await file.exists() || await file.length() == 0) {
      throw const FormatException(
        'El PDF no existe o está vacío; no se compartió.',
      );
    }
    if (isCancelled()) throw const ExecutionCancelled();
    return (contact: request.contact, file: file);
  }

  /// Exige gramática cerrada con identidad delimitada; no interpreta instrucciones libres.
  static _ArtifactRequest? _parse(String goal) {
    if (!recognizes(goal)) {
      return null;
    }
    final named = _namedPattern.firstMatch(goal);
    final catalog = _catalogPattern.firstMatch(goal);
    if (named == null && catalog == null) {
      throw const FormatException(
        'Usa: Comparte el producto "nombre exacto" con "destinatario"; '
        'Comparte el catálogo PDF con "destinatario"; o '
        'Comparte el PDF "archivo.pdf" con "destinatario".',
      );
    }
    final contact = jsonDecode(named?[3] ?? catalog![1]!) as String;
    final name = named == null ? null : jsonDecode(named[2]!) as String;
    if (contact.trim().isEmpty ||
        RegExp(r'["\\\r\n]').hasMatch(contact) ||
        (name != null && (name.isEmpty || name.contains('\n')))) {
      throw const FormatException(
        'Indica nombre y destinatario válidos; el destinatario no admite '
        'comillas internas, barras inversas ni saltos de línea.',
      );
    }
    return (
      kind: named == null
          ? 'catalogo'
          : named[1]!.toLowerCase() == 'producto'
          ? 'producto'
          : 'pdf',
      name: name,
      contact: contact,
    );
  }

  /// Copia solo el producto único persistido; precio, stock y disponibilidad se conservan.
  static BusinessFacts _selectedFacts(
    BusinessFacts facts,
    _ArtifactRequest request,
  ) {
    if (request.kind == 'catalogo') {
      if (facts.products.isEmpty) {
        throw const FormatException(
          'El catálogo real no tiene productos guardados.',
        );
      }
      return facts;
    }
    final products = facts.products
        .where((p) => p.name == request.name)
        .toList();
    if (products.length != 1) {
      throw FormatException(
        products.isEmpty
            ? 'No existe el producto "${request.name}". Usa su nombre exacto del catálogo.'
            : 'Hay varios productos llamados "${request.name}"; aclara el catálogo antes de compartir.',
      );
    }
    return facts.copyWith(products: [products.single]);
  }

  /// Busca PDF exacto en el negocio configurado, sin elegir otra biblioteca por fecha.
  static Future<File> _existingPdf(BusinessFacts facts, String name) async {
    if (facts.businessName.trim().isEmpty) {
      throw const FormatException(
        'Configura el nombre del negocio para identificar su biblioteca de PDF.',
      );
    }
    final documents = await _library.list(
      facts.businessName,
      BusinessDocumentLibrary.allCategory,
    );
    final matches = documents.where((d) => d.isPdf && d.name == name).toList();
    if (matches.length != 1) {
      throw FormatException(
        matches.isEmpty
            ? 'No hay un PDF llamado "$name" en la biblioteca de este negocio.'
            : 'Hay varios PDF llamados "$name"; renómbralos para identificar uno.',
      );
    }
    return matches.single.file;
  }
}
