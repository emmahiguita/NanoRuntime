import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/nano_runtime_api.dart';
import '../../automation/application/automation_feedback_presenter.dart';
import '../../automation/engine/voice/conversation/conversational_world_state.dart';
import '../../automation/engine/voice/conversation/grounding_resolver.dart';
import '../../automation/engine/voice/voice_backends.dart';
import '../../automation/engine/voice/voice_runtime.dart';

/// Coordina la sesión de voz, grounding de conversación y TTS/STT.
class ChatVoiceCoordinator {
  final Ref _ref;
  final SpeechRecognitionBackend _recognition;
  final SpeechSynthesisBackend _synthesis;
  VoiceSessionManager? _voiceSessionCache;
  bool _voiceConversationActive = false;

  ChatVoiceCoordinator(
    Ref ref, {
    SpeechRecognitionBackend? recognition,
    SpeechSynthesisBackend? synthesis,
  }) : _ref = ref,
       _recognition = recognition ?? const AndroidSpeechRecognitionBackend(),
       _synthesis =
           synthesis ??
           AndroidSpeechSynthesisBackend(
             enabled: () => ref.read(settingsProvider).voiceEnabled,
           );

  bool get isVoiceConversationActive => _voiceConversationActive;

  VoiceSessionManager get voiceSession =>
      _voiceSessionCache ??= VoiceSessionManager(
        recognition: _recognition,
        synthesis: _synthesis,
        resolveGoal: resolveVoiceGoal,
      );

  /// Resuelve pronombres y puebla el world state antes de ejecutar la orden de voz.
  Future<String> resolveVoiceGoal(String transcript) async {
    final session = voiceSession;
    final target = extractExplicitTarget(transcript);
    if (target != null && target.isNotEmpty) {
      session.world.remember(
        target,
        ResolvedReference(
          entity: target,
          source: ReferenceSource.explicit,
          confidence: 1.0,
          evidence: 'utterance',
          timestamp: DateTime.now(),
        ),
      );
      session.world.setActive(person: target);
    } else {
      final sender = await latestNotificationSender();
      if (sender != null && sender.isNotEmpty) {
        session.world.setActive(person: sender);
        session.world.remember(
          sender,
          ResolvedReference(
            entity: sender,
            source: ReferenceSource.notification,
            confidence: 0.85,
            evidence: 'notification sender',
            timestamp: DateTime.now(),
          ),
        );
      }
    }
    return const TranscriptResolver().resolveTranscript(
      transcript,
      session.world,
    );
  }

  String? extractExplicitTarget(String transcript) {
    final m = RegExp(
      r'\ba\s+([A-Za-zÁÉÍÓÚÑáéíóúñ]{2,})',
    ).firstMatch(transcript);
    return m?.group(1);
  }

  /// Sender de la notificación activa más reciente para grounding.
  Future<String?> latestNotificationSender() async {
    try {
      final rows = await NanoRuntimeApi.instance.listActiveNotifications();
      for (final raw in rows) {
        if (raw is Map && raw['sender'] is String) {
          final s = (raw['sender'] as String).trim();
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Habla la respuesta si la voz está habilitada.
  Future<void> speakText(String text) async {
    if (!_ref.read(settingsProvider).voiceEnabled) return;
    if (text.trim().isNotEmpty) {
      await voiceSession.respond(automationSpokenReason(text));
    }
  }

  /// Inicia el modo de conversación continua.
  Future<bool> startVoiceConversation({
    required Future<void> Function(String transcript) onTranscriptReady,
    required String? Function() getLastAiText,
    required bool Function() isMounted,
  }) async {
    if (_voiceConversationActive) return false;
    _voiceConversationActive = true;
    var turnsCompleted = 0;
    try {
      await voiceSession.respond('Hola, soy Nano. ¿En qué puedo ayudarte?');
      await voiceSession.waitForSpeechEnd();

      while (_voiceConversationActive && isMounted()) {
        final turn = await voiceSession.pushToTalk();
        if (!_voiceConversationActive) break;
        final transcript = turn?.transcript.trim() ?? '';
        if (transcript.isEmpty) break;

        await onTranscriptReady(transcript);
        turnsCompleted++;
        if (!_voiceConversationActive) break;

        final aiText = getLastAiText();
        if (aiText == null || aiText.isEmpty) break;
        await voiceSession.respondAndListen(automationSpokenReason(aiText));
      }
    } finally {
      _voiceConversationActive = false;
    }
    return turnsCompleted > 0;
  }

  /// Detiene el modo conversación continua.
  void stopVoiceConversation() {
    if (!_voiceConversationActive) return;
    _voiceConversationActive = false;
    unawaited(voiceSession.stop());
  }

  Future<void> dispose() async {
    _voiceConversationActive = false;
    final session = _voiceSessionCache;
    _voiceSessionCache = null;
    if (session != null) {
      await session.dispose();
    }
  }
}
