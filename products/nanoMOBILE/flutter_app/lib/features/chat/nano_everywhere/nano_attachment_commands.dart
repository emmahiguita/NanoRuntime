import '../../automation/presentation/widgets/automation_input_attachment.dart';
import 'nano_prepared_attachment.dart';

/// Usa el mismo contrato de archivo que la barra de Automatización. La capa
/// del búho conserva su selección; esta función solo prepara el texto canónico.
String prepareNanoAttachment(String input, NanoPreparedAttachment? file) =>
    prepareAutomationDraft(
      input,
      file == null
          ? null
          : AutomationInputAttachment(name: file.name, path: file.path),
    ).goal;
