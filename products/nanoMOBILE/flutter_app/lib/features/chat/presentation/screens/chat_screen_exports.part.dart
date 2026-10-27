part of 'chat_screen.dart';

extension _ChatScreenExports on _ChatScreenState {
  Future<void> _exportFullChatPdf(ChatState state) async {
    final buffer = StringBuffer();
    for (final m in state.messages) {
      final sender = m.sender == MessageSender.user ? 'USUARIO' : 'NANO AI';
      buffer.writeln('### $sender:\n${m.text}\n');
    }
    await PdfReportService.exportReport(
      title: 'Transcripción de Conversación NanoAI',
      content: buffer.toString(),
      modelName: state.activeModel.isEmpty ? 'Nano Runtime' : state.activeModel,
    );
  }

  Future<void> _exportFullChatMarkdown(ChatState state) async {
    final buffer = StringBuffer();
    for (final m in state.messages) {
      final sender = m.sender == MessageSender.user ? 'Usuario' : 'Nano AI';
      buffer.writeln('**$sender:**\n\n${m.text}\n\n---');
    }
    await PdfReportService.exportMarkdown(
      title: 'Conversación NanoAI',
      content: buffer.toString(),
      modelName: state.activeModel.isEmpty ? 'Nano Runtime' : state.activeModel,
    );
  }
}
