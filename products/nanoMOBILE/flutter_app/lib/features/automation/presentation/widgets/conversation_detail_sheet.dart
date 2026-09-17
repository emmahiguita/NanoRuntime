import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/automation_coordinator_provider.dart';
import '../../engine/agent_dependencies.dart'
    show conversationAssignmentStoreProvider, conversationMemoryStoreProvider;
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_key.dart'
    show resolveConversationIdentity;
import '../../personal_agent/application/persona_context.dart'
    show personaContextProvider;
import '../../engine/notifications/notification_object.dart';
import '../../engine/platform/whatsapp_media_share.dart';
import '../../executors/notification_executor.dart' show DeviceNotification;
import '../../executors/notification_executor_provider.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import '../../personal_agent/domain/personal_memory.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/business/fact_selector.dart';
import '../automation_visual_theme.dart';

part 'conversation_detail_sheet_view.dart';
part 'conversation_detail_dialogs.dart';

class ConversationDetailSheet extends ConsumerStatefulWidget {
  final ConversationSummaryItem item;

  static const List<String> _sfFallback = [
    '.SF UI Text',
    '.SF UI Display',
    'SF Pro Text',
    'SF Pro Display',
    'Inter',
    'Roboto',
  ];

  const ConversationDetailSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, ConversationSummaryItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (ctx) => ConversationDetailSheet(item: item),
    );
  }

  @override
  ConsumerState<ConversationDetailSheet> createState() =>
      _ConversationDetailSheetState();
}

class _ConversationDetailSheetState
    extends ConsumerState<ConversationDetailSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isHumanOwned = false;
  bool _busy = false;
  String? _statusText;
  List<String> _suggestions = const [];
  late ConversationAgentId _agentId;

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _isHumanOwned = widget.item.humanOwns;
    _agentId = widget.item.agentId;
    if (widget.item.hasPendingReply && widget.item.pendingReplyText != null) {
      _inputController.text = widget.item.pendingReplyText!;
    }
    if (widget.item.pendingSuggestions.isNotEmpty) {
      _suggestions = widget.item.pendingSuggestions;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleOwnership(bool human) async {
    setState(() {
      _isHumanOwned = human;
    });
    final store = ref.read(conversationOwnershipStoreProvider);
    await store.load();
    await store.setOwner(
      widget.item.conversationId,
      human ? ConversationOwner.human : ConversationOwner.bot,
    );
    ref.invalidate(conversationHubListProvider);
  }

  Future<void> _transferAgent(ConversationAgentId target) async {
    if (target == _agentId || _busy) return;
    setState(() {
      _busy = true;
      _statusText = 'Transfiriendo a ${target.displayName}...';
    });
    try {
      final memory = ref
          .read(conversationMemoryStoreProvider)
          .memoryFor(widget.item.conversationId);
      final minimalContext = <String>[
        if (memory?.activeTopic?.isNotEmpty == true)
          'tema=${memory!.activeTopic}',
        if (memory?.unresolvedObligations.isNotEmpty == true)
          'pendiente=${memory!.unresolvedObligations.take(2).join(' | ')}',
      ].join('; ');
      await ref
          .read(conversationAssignmentStoreProvider)
          .transfer(
            widget.item.conversationId,
            target,
            reason: 'transferencia explícita desde Centro de Conversaciones',
            minimalContext: minimalContext,
          );
      if (!mounted) return;
      setState(() {
        _agentId = target;
        _statusText =
            'Transferida a ${target.displayName}. La memoria anterior no se mezcló.';
      });
      ref.invalidate(conversationHubListProvider);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _statusText = 'No se pudo transferir: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateAiSuggestion() async {
    setState(() {
      _busy = true;
      _statusText = 'Generando opciones con la IA local...';
    });
    try {
      final executor = ref.read(notificationExecutorProvider);
      final composer = ref.read(conversationReplyComposerProvider);

      final list = await executor.list(limit: 10);
      final targetNotif = list
          .where(
            (n) =>
                n.text == widget.item.lastMessage ||
                n.sender == widget.item.displayName,
          )
          .firstOrNull;

      final notifObj = targetNotif != null
          ? targetNotif.toNotificationObject()
          : NotificationObject.fromMap({
              'key': 'hub_${widget.item.conversationId}',
              'package': widget.item.packageName,
              'title': widget.item.displayName,
              'text': widget.item.lastMessage,
              'messageText': widget.item.lastMessage,
              'sender': widget.item.displayName,
              'conversationId': widget.item.conversationId,
              'postTime': widget.item.lastAtMs,
              'canReply': true,
            });

      final draftResult = await composer.compose(notifObj);
      final allOptions = <String>[];

      if (draftResult != null && draftResult.hasReply) {
        allOptions.add(draftResult.text.trim());
        for (final s in draftResult.suggestions) {
          final clean = s.trim();
          if (clean.isNotEmpty && !allOptions.contains(clean)) {
            allOptions.add(clean);
          }
        }
      }

      // 1. Inyección de hechos de negocio fácticos si el mensaje lo amerita
      final rawMsg = widget.item.lastMessage.trim();
      final businessFacts = ref.read(businessFactsNotifierProvider);
      if (!businessFacts.isEmpty && rawMsg.isNotEmpty) {
        final selection = selectFactsForMessage(rawMsg, businessFacts);
        if (selection.isNotEmpty) {
          if (selection.products.isNotEmpty) {
            for (final p in selection.products.take(2)) {
              final stockLabel = p.stock != null
                  ? (p.stock! > 0 ? ' (stock disponible)' : ' (por encargo)')
                  : '';
              allOptions.add('El ${p.name} tiene un valor de ${p.priceLabel}$stockLabel.');
            }
          }
          if (selection.hours.isNotEmpty) {
            allOptions.add('Nuestro horario de atención es: ${selection.hours}.');
          }
          if (selection.location.isNotEmpty) {
            allOptions.add('Estamos ubicados en: ${selection.location}.');
          }
          if (selection.payments.isNotEmpty) {
            allOptions.add('Recibimos pagos por: ${selection.payments}.');
          }
          if (selection.delivery.isNotEmpty) {
            allOptions.add('Manejamos servicio de envíos: ${selection.delivery}.');
          }
        }
      }

      // 2. Opciones complementarias multi-tono y semánticas
      final msgNorm = rawMsg.toLowerCase();
      if (msgNorm.contains('hola') ||
          msgNorm.contains('buenas') ||
          msgNorm.contains('que mas') ||
          msgNorm.contains('quiubo')) {
        allOptions.addAll([
          '¡Hola! Todo muy bien por acá gracias a Dios, ¿y tú cómo estás?',
          '¡Hola! Por acá todo tranquilo, cuéntame.',
          '¡Buenas! ¿En qué te puedo colaborar hoy?',
        ]);
      } else if (msgNorm.contains('como estas') ||
          msgNorm.contains('como te va') ||
          msgNorm.contains('que tal') ||
          msgNorm.contains('todo bien')) {
        allOptions.addAll([
          'Bien también, todo en orden por acá.',
          'Todo bien por acá gracias a Dios, ¿y tú qué tal?',
          'Por acá todo tranquilo en lo mío, ¿cómo te ha ido a ti?',
        ]);
      } else if (msgNorm.contains('y tu') || msgNorm.contains('y vos')) {
        allOptions.addAll([
          'Bien también, todo tranquilo.',
          'Por acá todo bien también, gracias por preguntar.',
          'Todo en orden por acá.',
        ]);
      } else if (msgNorm.contains('que vas hacer') ||
          msgNorm.contains('que vas a hacer') ||
          msgNorm.contains('que planes') ||
          msgNorm.contains('que haces') ||
          msgNorm.contains('en que andas')) {
        allOptions.addAll([
          'Por acá tranquilo por ahora, más tarde te voy avisando.',
          'Aún no sé seguro qué haga más tarde, te confirmo en un rato.',
          'Por ahora aquí en lo mío, más tarde miro qué sale.',
        ]);
      } else if (msgNorm.contains('cuanto') ||
          msgNorm.contains('precio') ||
          msgNorm.contains('vale') ||
          msgNorm.contains('costo')) {
        allOptions.addAll([
          'Claro que sí, déjame revisar y ya mismo te confirmo.',
          'Hola, ¿para qué fecha o en qué color lo necesitarías?',
          'Con gusto te paso la información detallada.',
        ]);
      } else if (msgNorm.contains('tarea') ||
          msgNorm.contains('ayuda') ||
          msgNorm.contains('favor') ||
          msgNorm.contains('duda') ||
          msgNorm.contains('pregunta')) {
        allOptions.addAll([
          'De una, cuéntame de qué se trata.',
          '¡Claro que sí! Dime en qué te puedo colaborar.',
          'Cuéntame con calma y lo miramos.',
        ]);
      } else if (msgNorm.contains('gracias')) {
        allOptions.addAll([
          '¡De una, con mucho gusto!',
          'Por acá a la orden para lo que necesites.',
          'De una, fresco.',
        ]);
      } else if (allOptions.isEmpty) {
        allOptions.addAll([
          'Dale, de una.',
          'Perfecto, entendido.',
          'Listo, muchas gracias.',
        ]);
      }

      // Deduplicar respetando orden de relevancia
      final uniqueOptions = <String>[];
      for (final opt in allOptions) {
        final clean = opt.trim();
        if (clean.isNotEmpty && !uniqueOptions.contains(clean)) {
          uniqueOptions.add(clean);
        }
        if (uniqueOptions.length >= 6) break;
      }

      if (mounted) {
        setState(() {
          _suggestions = uniqueOptions;
          if (uniqueOptions.isNotEmpty) {
            _inputController.text = uniqueOptions.first;
          }
          _statusText = uniqueOptions.length > 1
              ? '${uniqueOptions.length} opciones listas (Directa, Cálida, Factual y Seguimiento).'
              : 'Sugerencia generada con el catálogo de datos';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'No se pudo generar borrador: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  DeviceNotification? _findMatchingNotification(List<DeviceNotification> list) {
    final convId = widget.item.conversationId.trim();
    final displayName = widget.item.displayName.trim().toLowerCase();
    final notifKey = widget.item.notificationKey?.trim();

    // 1. Coincidencia exacta por notificationKey directa si existe
    if (notifKey != null && notifKey.isNotEmpty) {
      for (final n in list) {
        if (n.canReply && n.key == notifKey) return n;
      }
    }

    // 2. Coincidencia exacta por identidad canónica de conversación (ConversationIdentity)
    if (convId.isNotEmpty) {
      for (final n in list) {
        if (!n.canReply) continue;
        final nIdentity = resolveConversationIdentity(n.toNotificationObject());
        if (nIdentity.key.id.isNotEmpty && nIdentity.key.id == convId) {
          return n;
        }
      }
    }

    // 3. Coincidencia por shortcutId, senderKey o conversationId factual de Android
    if (convId.isNotEmpty) {
      for (final n in list) {
        if (!n.canReply) continue;
        if (n.shortcutId.isNotEmpty &&
            (convId == n.shortcutId ||
                convId.contains('shortcut:${n.shortcutId}') ||
                convId.endsWith(n.shortcutId))) {
          return n;
        }
        if (n.senderKey.isNotEmpty &&
            (convId == n.senderKey ||
                convId.contains('person:${n.senderKey}') ||
                convId.endsWith(n.senderKey))) {
          return n;
        }
        if (n.conversationId.isNotEmpty &&
            (convId == n.conversationId ||
                convId.contains('conv:${n.conversationId}') ||
                convId.endsWith(n.conversationId))) {
          return n;
        }
      }
    }

    // 4. Coincidencia por dígitos telefónicos / JID (ambos DEBEN tener >= 7 dígitos)
    final targetDigits = RegExp(r'\d{7,15}').firstMatch(convId)?.group(0) ??
        RegExp(r'\d{7,15}').firstMatch(displayName)?.group(0);

    if (targetDigits != null && targetDigits.length >= 7) {
      for (final n in list) {
        if (!n.canReply) continue;
        for (final candidate in [n.conversationId, n.senderKey, n.shortcutId, n.title]) {
          final nDigits = RegExp(r'\d{7,15}').firstMatch(candidate)?.group(0);
          if (nDigits != null && nDigits.length >= 7) {
            if (targetDigits == nDigits ||
                targetDigits.endsWith(nDigits) ||
                nDigits.endsWith(targetDigits)) {
              return n;
            }
          }
        }
      }
    }

    // 5. Coincidencia por nombre exacto de contacto (LONGITUD >= 3, NUNCA genérico ni vacío)
    final isGenericName = displayName.isEmpty ||
        displayName.startsWith('contacto whatsapp') ||
        displayName.startsWith('chat de whatsapp') ||
        displayName == 'whatsapp' ||
        displayName.length < 3;

    if (!isGenericName) {
      for (final n in list) {
        if (!n.canReply) continue;
        final nTitle = n.title.trim().toLowerCase();
        final nSender = n.sender.trim().toLowerCase();
        final nConvTitle = n.conversationTitle.trim().toLowerCase();

        // Igualdad exacta únicamente (NUNCA substrings contra campos vacíos)
        if (nTitle == displayName ||
            (nSender.isNotEmpty && nSender == displayName) ||
            (nConvTitle.isNotEmpty && nConvTitle == displayName)) {
          return n;
        }
      }
    }

    // 6. Fail-closed total: jamás devolver la primera de la lista ni adivinar
    return null;
  }

  String? _resolvePhoneDigits(ConversationMemoryStore store) {
    final direct = RegExp(r'\d{7,15}').firstMatch(widget.item.conversationId)?.group(0) ??
        RegExp(r'\d{7,15}').firstMatch(widget.item.displayName)?.group(0);
    if (direct != null && direct.length >= 7 && !direct.startsWith('24314')) {
      return direct;
    }

    final entries = _resolveEntries(store);
    for (final e in entries) {
      final match = RegExp(r'\+?(\d{10,15})').firstMatch(e.text.replaceAll(' ', ''));
      if (match != null) {
        return match.group(1);
      }
    }

    final personaContext = ref.read(personaContextProvider);
    final rel = personaContext.relationshipFor(
      widget.item.displayName,
      conversationId: widget.item.conversationId,
    );
    final relPhone = rel?.facts['phone'] ?? rel?.facts['telefono'];
    if (relPhone != null && relPhone.isNotEmpty) {
      final digits = RegExp(r'\d{7,15}').firstMatch(relPhone)?.group(0);
      if (digits != null && digits.length >= 7) return digits;
    }

    return null;
  }

  Future<void> _sendReply() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _statusText = 'Enviando mensaje...';
    });
    try {
      if (widget.item.hasPendingReply && widget.item.pendingReplyId != null) {
        final pendingStore = ref.read(pendingReplyStoreProvider);
        await pendingStore.updateDraftText(widget.item.pendingReplyId!, text);
        await pendingStore.approve(widget.item.pendingReplyId!);
      }

      final executor = ref.read(notificationExecutorProvider);
      final list = await executor.list(limit: 50);
      final targetNotif = _findMatchingNotification(list);

      if (targetNotif != null) {
        final replyResult = await executor.confirmAndReply(targetNotif, text);
        if (mounted) {
          setState(() {
            _inputController.clear();
            _statusText = replyResult.isAccepted
                ? 'Mensaje entregado en 2do plano sin abrir WhatsApp'
                : 'No se pudo entregar en 2do plano: ${replyResult.code}';
          });
        }
      } else {
        // Sin notificación activa para responder por RemoteInput
        const share = WhatsAppMediaShare();
        final hasA11y = await share.isAccessibilityEnabled();
        final memoryStore = ref.read(conversationMemoryStoreProvider);
        final phoneDigits = _resolvePhoneDigits(memoryStore);

        if (phoneDigits == null || phoneDigits.length < 7) {
          if (mounted) {
            setState(() {
              _statusText =
                  'No hay notificación activa ni teléfono registrado para ${widget.item.displayName}.';
            });
            await _showMissingPhoneDialog(context, widget.item.displayName);
          }
          return;
        }

        final contact = phoneDigits;

        if (hasA11y) {
          if (mounted) {
            setState(() {
              _statusText = '⚡ Despachando con retorno automático flash...';
            });
          }
          final ok = await share.openChat(
            contact: contact,
            text: text,
            packageName: widget.item.packageName,
            autoSend: true,
          );
          if (mounted) {
            setState(() {
              _inputController.clear();
              _statusText = ok
                  ? 'Mensaje despachado y retornado a Nano'
                  : 'No se pudo abrir el chat de WhatsApp';
            });
          }
        } else {
          // Si no hay accesibilidad ni notificación: NO abrir WhatsApp sin confirmación
          if (mounted) {
            setState(() {
              _busy = false;
              _statusText = 'Acción requerida para enviar sin salir de Nano';
            });
            final action = await _showNoA11yOptionsModal(context, share, contact, text);
            if (action == 'sent_whatsapp') {
              if (mounted) {
                setState(() {
                  _inputController.clear();
                  _statusText = 'Chat abierto en WhatsApp';
                });
              }
            }
            return;
          }
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final memoryStore = ref.read(conversationMemoryStoreProvider);
      memoryStore.appendOutbound(
        widget.item.conversationId,
        text,
        kind: ConversationMemoryEntryKind.outboundDispatched,
        atMs: nowMs,
      );
      ref.read(eventDedupeStoreProvider).recordVerifiedOutbound(
        widget.item.conversationId,
        text,
        atMs: nowMs,
      );

      // WA-LEARN-02: Autoaprendizaje en SQLite FTS4 y Memoria de Corrección
      final lastMsg = widget.item.lastMessage.trim();
      final isRealIncoming = lastMsg.isNotEmpty && !RegExp(r'^\+?[0-9\s\-]+$').hasMatch(lastMsg);
      if (isRealIncoming) {
        try {
          final originalDraft = widget.item.pendingReplyText?.trim();
          final isCorrection = originalDraft != null &&
              originalDraft.isNotEmpty &&
              originalDraft != text;

          await PersonaRepository.instance.addExample(
            personaKey: 'owner',
            incomingText: lastMsg,
            body: text,
            source: isCorrection ? 'correction' : 'messaging_center_learning',
            tone: {
              'ownerVerified': 'true',
              'kind': 'paired',
              if (isCorrection) 'correctedFrom': originalDraft,
            },
          );

          if (isCorrection) {
            await PersonaRepository.instance.savePersonalMemory(
              PersonalMemory(
                scopeKey: 'owner',
                key: 'correccion_estilo',
                value: 'Preferir "$text" sobre "$originalDraft"',
                kind: 'stylePreference',
                observedAt: DateTime.now().millisecondsSinceEpoch,
                metadata: {
                  'suggested': originalDraft,
                  'corrected': text,
                  'input': lastMsg,
                },
              ),
            );
            debugPrint('[learning] Corrección registrada: "$originalDraft" -> "$text"');
          } else {
            debugPrint('[learning] Par aprendido orgánicamente en FTS4: "$lastMsg" -> "$text"');
          }
        } catch (e) {
          debugPrint('[learning] Error registrando aprendizaje en PersonaRepository: $e');
        }
      }

      ref.invalidate(conversationHubListProvider);
      ref.read(conversationHubVersionProvider.notifier).state++;

      if (widget.item.hasPendingReply && widget.item.pendingReplyId != null) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _statusText = 'Error enviando mensaje: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _cleanName(String raw) {
    if (raw.contains('|')) {
      raw = raw.split('|').last;
    }
    if (raw.contains('shortcut:') ||
        raw.contains('@g.us') ||
        raw.contains('@s.whatsapp.net') ||
        raw.startsWith('whatsapp/')) {
      final digits = RegExp(r'\d{8,15}').firstMatch(raw)?.group(0);
      if (digits != null) {
        return 'Contacto WhatsApp ($digits)';
      }
      return 'Chat de WhatsApp';
    }
    return raw;
  }

  List<ConversationMemoryEntry> _resolveEntries(ConversationMemoryStore store) {
    final convId = widget.item.conversationId.trim();
    final allEntries = <ConversationMemoryEntry>[];
    final seen = <String>{};

    void addEntries(List<ConversationMemoryEntry>? list) {
      if (list == null) return;
      for (final e in list) {
        final key = '${e.atMs}_${e.kind.name}_${e.text.trim()}';
        if (seen.add(key)) {
          allEntries.add(e);
        }
      }
    }

    // 1. Memoria directa del ID solicitado
    if (convId.isNotEmpty) {
      addEntries(store.memoryFor(convId)?.entries);
    }

    // 2. Extraer huella conversacional (ej: shortcut:243142846578833@lid o 18636023784)
    final fingerprint =
        convId.contains('/-/') ? convId.split('/-/').last : convId;
    final cleanFingerprint = fingerprint
        .replaceFirst('shortcut:', '')
        .replaceFirst('person:', '')
        .replaceFirst('conv:', '')
        .trim();

    // 3. Buscar en todos los IDs conocidos de memoria que coincidan con la huella
    if (cleanFingerprint.isNotEmpty) {
      for (final id in store.knownConversationIds()) {
        if (id == convId) continue;
        final idFingerprint = id.contains('/-/') ? id.split('/-/').last : id;
        final cleanIdFp = idFingerprint
            .replaceFirst('shortcut:', '')
            .replaceFirst('person:', '')
            .replaceFirst('conv:', '')
            .trim();

        if (cleanFingerprint == cleanIdFp) {
          addEntries(store.memoryFor(id)?.entries);
        }
      }
    }

    // 4. Buscar por coincidencia de nombre de remitente en memoria
    final targetName = widget.item.displayName.trim().toLowerCase();
    if (allEntries.isEmpty &&
        targetName.isNotEmpty &&
        targetName.length >= 3 &&
        !targetName.startsWith('contacto whatsapp') &&
        !targetName.startsWith('chat de whatsapp')) {
      for (final id in store.knownConversationIds()) {
        final candidate = store.memoryFor(id);
        if (candidate != null &&
            candidate.entries.any(
              (e) => e.sender.trim().toLowerCase() == targetName,
            )) {
          addEntries(candidate.entries);
        }
      }
    }

    if (allEntries.isNotEmpty) {
      allEntries.sort((a, b) => a.atMs.compareTo(b.atMs));
      return allEntries;
    }

    return const <ConversationMemoryEntry>[];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(conversationHubVersionProvider);
    final visual = AutomationVisual.of(context);
    final memoryStore = ref.watch(conversationMemoryStoreProvider);
    final entries = _resolveEntries(memoryStore);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: visual.isDark
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.70),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: visual.isDark ? 0.55 : 0.20),
              blurRadius: 35,
              spreadRadius: -5,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Fondo vivo celestial de Automatización (Búho cósmico y auroras fluidas)
            AutomationBackdrop(scrimOpacity: visual.isDark ? 0.20 : 0.32),

            // 2. Capa de cristal líquido transparente con desenfoque óptico profundo
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: visual.isDark
                          ? [
                              const Color(0x350F172A), // ~20% vidrio slate oscuro
                              const Color(0x550B1120), // ~33% obsidiana translúcida
                            ]
                          : [
                              const Color(0x55FFFFFF), // 33% blanco cristal
                              const Color(0x75F1F5F9), // 46% slate claro cristalino
                            ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Resplandor superior de borde reflectivo
            Positioned(
              top: 0,
              left: 40,
              right: 40,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: visual.isDark ? 0.60 : 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 4. Contenido del chat con controles, mensajes y barra de envío
            SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: visual.isDark ? 0.45 : 0.65),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  _buildHeader(visual),
                  _buildControlBar(visual),
                  if (_statusText != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 16,
                      ),
                      color: visual.accent.withValues(alpha: 0.15),
                      child: Text(
                        _statusText!,
                        style: TextStyle(
                          color: visual.accent,
                          fontFamily: 'Inter',
                          fontFamilyFallback:
                              ConversationDetailSheet._sfFallback,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
                    child: entries.isEmpty
                        ? _buildFallbackLastMessage(visual)
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: entries.length,
                            itemBuilder: (ctx, idx) {
                              final entry = entries[idx];
                              final isInbound =
                                  entry.kind ==
                                  ConversationMemoryEntryKind.inbound;
                              return _buildChatBubble(
                                entry.text,
                                isInbound,
                                visual,
                              );
                            },
                          ),
                  ),
                  _buildBottomActionBar(visual),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
