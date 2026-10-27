import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/business/business_document_library.dart';
import 'business_document_library_dialog.dart';
import 'meta_attachment_picker.dart';

/// Comparte el selector existente de Nano, sin copiar su almacén ni enviar por intent.
Future<PlatformFile?> chooseMetaAttachment(
  BuildContext context,
  WidgetRef ref,
) async {
  final library = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Biblioteca de Nano'),
            onTap: () => Navigator.pop(ctx, true),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Archivo del teléfono'),
            onTap: () => Navigator.pop(ctx, false),
          ),
        ],
      ),
    ),
  );
  if (library == null || !context.mounted) return null;
  if (!library) return pickBoundedMetaAttachment();
  await ref.read(businessFactsNotifierProvider.notifier).ready;
  if (!context.mounted) return null;
  BusinessDocument? selected;
  bool tooMany = false;
  await BusinessDocumentLibraryDialog.show(
    context,
    ref.read(businessFactsNotifierProvider),
    onSendToChat: (docs) {
      if (docs.length == 1) {
        selected = docs.single;
      } else {
        tooMany = true;
      }
    },
  );
  if (tooMany) throw const FormatException('Selecciona un solo archivo.');
  final doc = selected;
  return doc == null ? null : readBoundedMetaLibraryFile(doc.file, doc.name);
}
