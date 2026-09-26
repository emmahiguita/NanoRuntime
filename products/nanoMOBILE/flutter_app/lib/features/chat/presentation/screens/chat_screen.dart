import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/widgets/navigation/nano_attach_sheet.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';
import '../widgets/chat_messages.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/widgets/live_animations.dart';
import 'package:nanoai/core/widgets/nano_components.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/pdf_report_service.dart';
import '../../nano_everywhere/nano_floating_wrapper.dart';

/// Pantalla Chat — identidad visual de Inicio (glassmorphism, sin AppBar).
///
/// Los nombres de estado y métodos son los REALES de ChatNotifier:
/// `send(text)`, `stop()`, `refreshEngine()`. El motor nunca se simula:
/// cuando no está disponible, el envío queda desactivado y la UI lo dice.
part 'chat_screen_conversation.part.dart';
part 'chat_screen_attachments.part.dart';
part 'chat_screen_layout.part.dart';
part 'chat_screen_actions.part.dart';
part 'chat_screen_menu.part.dart';
part 'chat_screen_exports.part.dart';
part 'chat_screen_landscape.part.dart';
part 'chat_screen_dialogs.part.dart';
part 'chat_screen_reading_mode.part.dart';
part 'chat_screen_reading_controls.part.dart';
part 'chat_screen_reading_text.part.dart';
part 'chat_screen_attachments_view.part.dart';
part 'chat_screen_reading_helpers.part.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  // NAV-BAR-FIX-01 — el campo de escritura del chat ES la barra universal del
  // shell (NanoInputScope). El dictado por voz escribe aquí y viaja a la
  // barra vía `initialText` del scope (antes iba a un TextEditingController
  // huérfano que ningún TextField mostraba: la voz estaba rota).
  String _dictatedText = '';

  // Voz usa SpeechRecognizer/TTS de Android. Cámara delega en la app del
  // sistema y la foto pasa por el clasificador ML Kit ya incluido.
  bool _listening = false;
  StreamSubscription<String>? _partialSub;
  // VOICE-NATURAL-01: conversación continua (hablar ↔ responder ↔ volver a
  // escuchar). _voiceState refleja la máquina de estados REAL del manager;
  // el loop vive en ChatNotifier (la voz es I/O del MISMO send()).
  bool _conversationActive = false;
  bool _isReadingMode = false;

  /// Máximo de caracteres de un archivo adjunto que se insertan en el input.
  static const _maxAttachChars = 8000;
  static const _maxAttachBytes = 64 * 1024;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _partialSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) => _buildChatScreen(context);
}
