import '../../platform/whatsapp_send_monitor.dart';
import '../../voice/execution_cancellation.dart';
import '../tool_call.dart';
import 'whatsapp_command_input.dart';

/// Ruta de comandos explícitos, separada del envío y la agenda. Los callbacks
/// conservan el handler real y su cancelación; no crean otro ejecutor ni modelo.
Future<String> runWhatsAppCommand(
  String input, {
  required Future<String> Function(ToolCall) openChat,
  required Future<String> Function(
    ToolCall, {
    ExecutionCancellationToken? cancellation,
  })
  sendMessage,
  required Future<String> Function(
    ToolCall, {
    ExecutionCancellationToken? cancellation,
  })
  shareFile,
  ExecutionCancellationToken? cancellation,
}) async {
  // Diagnóstico sin efectos: permite comprobar el intento real desde Nano.
  if (input.trim() == '--estado') {
    final current = await WhatsAppSendMonitor().status();
    return '[completed] WhatsApp local: $current';
  }
  final command = WhatsAppCommandInput.parse(input);
  if (command == null) {
    return 'Uso: @whatsapp "Nombre completo", +número o @usuario [mensaje]. Para archivo: --archivo ruta';
  }
  final message = command.message;
  // --archivo conserva la ruta completa (incluidos espacios). No interpreta
  // un enlace remoto como archivo ni descarga documentos de forma implícita.
  if (message.startsWith('--archivo ')) {
    return shareFile(
      ToolCall(
        tool: 'whatsapp.share_file',
        args: {
          'contact': command.contact,
          'path': message.substring(10).trim(),
        },
      ),
      cancellation: cancellation,
    );
  }
  final call = ToolCall(
    tool: message.isEmpty ? 'whatsapp.open_chat' : 'whatsapp.send_message',
    args: {
      'contact': command.contact,
      'packageName': 'com.whatsapp',
      if (cancellation?.executionId != null)
        'executionId': cancellation!.executionId,
      if (message.isNotEmpty) 'text': message,
    },
  );
  // El comando humano con texto es consentimiento explícito para enviar.
  return message.isEmpty
      ? openChat(call)
      : sendMessage(call, cancellation: cancellation);
}
