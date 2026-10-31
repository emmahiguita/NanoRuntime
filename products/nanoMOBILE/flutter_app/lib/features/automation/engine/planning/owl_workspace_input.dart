/// Órdenes del espacio local del búho. Solo reconoce intenciones explícitas;
/// no interpreta los mensajes observados en WhatsApp como instrucciones.
abstract final class OwlWorkspaceInput {
  static String? kind(String input) {
    final text = input.trim().toLowerCase().replaceAll(RegExp(r'[.!]$'), '');
    if (RegExp(
      r'^importa(?:r)? (?:el )?historial(?: de whatsapp)?$',
    ).hasMatch(text)) {
      return 'import';
    }
    if (RegExp(
      r'^analiza(?:r)? (?:el |ultimo |último )?historial(?: completo)? importado$',
    ).hasMatch(text)) {
      return 'analyze';
    }
    if (RegExp(r'^prepara(?:r)? qa de whatsapp(?: con .+)?$').hasMatch(text)) {
      return 'prepare_qa';
    }
    if (text == 'ejecuta qa de whatsapp') return 'run_qa';
    if (text == 'exporta informe qa') return 'export_qa';
    if (text == 'historial qa') return 'history_qa';
    if (text == 'ver pantalla de whatsapp' || text == '@leer_pantalla') {
      return 'screen';
    }
    return null;
  }
}
