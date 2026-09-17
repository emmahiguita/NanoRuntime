part of 'conversation_detail_sheet.dart';

extension _ConversationDetailSheetView on _ConversationDetailSheetState {
  Widget _buildHeader(AutomationVisualPalette visual) {
    final title = _cleanName(widget.item.displayName);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: visual.isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0x33CBD5E1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [visual.accent, visual.accent.withValues(alpha: 0.65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: visual.accent.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: visual.text,
                    fontFamily: 'Inter',
                    fontFamilyFallback: ConversationDetailSheet._sfFallback,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34C759),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${widget.item.appLabel} · ${_agentId.displayName}',
                      style: TextStyle(
                        color: visual.textMuted,
                        fontFamily: 'Inter',
                        fontFamilyFallback: ConversationDetailSheet._sfFallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<ConversationAgentId>(
            tooltip: 'Transferir conversación',
            enabled: !_busy,
            initialValue: _agentId,
            onSelected: _transferAgent,
            itemBuilder: (_) => [
              for (final agent in ConversationAgentId.values)
                PopupMenuItem(
                  value: agent,
                  child: Text('Asignar a ${agent.displayName}'),
                ),
            ],
            icon: Icon(Icons.swap_horiz_rounded, color: visual.text, size: 20),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: visual.textMuted.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: Icon(CupertinoIcons.xmark, size: 16, color: visual.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(AutomationVisualPalette visual) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: visual.isDark ? 0.07 : 0.40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: visual.isDark ? 0.16 : 0.60),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: visual.isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. IA Activa (Bot)
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleOwnership(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: !_isHumanOwned
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x3800FF88),
                            Color(0x1F00FF88),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: !_isHumanOwned
                      ? Border.all(
                          color: const Color(0xFF00FF88).withValues(alpha: 0.65),
                          width: 1.2,
                        )
                      : null,
                  boxShadow: !_isHumanOwned
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00FF88).withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: !_isHumanOwned
                            ? const Color(0xFF00FF88)
                            : visual.textMuted.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        boxShadow: !_isHumanOwned
                            ? [
                                const BoxShadow(
                                  color: Color(0xFF00FF88),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.sparkles,
                      size: 15,
                      color: !_isHumanOwned
                          ? const Color(0xFF00FF88)
                          : visual.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'IA Activa (Bot)',
                      style: TextStyle(
                        color: !_isHumanOwned
                            ? const Color(0xFF00FF88)
                            : visual.textMuted,
                        fontFamily: 'Inter',
                        fontFamilyFallback: ConversationDetailSheet._sfFallback,
                        fontSize: 13,
                        fontWeight: !_isHumanOwned
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // 2. Control Humano
          Expanded(
            child: GestureDetector(
              onTap: () => _toggleOwnership(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: _isHumanOwned
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x38007AFF),
                            Color(0x1F007AFF),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: _isHumanOwned
                      ? Border.all(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.65),
                          width: 1.2,
                        )
                      : null,
                  boxShadow: _isHumanOwned
                      ? [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isHumanOwned
                            ? const Color(0xFF007AFF)
                            : visual.textMuted.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        boxShadow: _isHumanOwned
                            ? [
                                const BoxShadow(
                                  color: Color(0xFF007AFF),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.person_fill,
                      size: 15,
                      color: _isHumanOwned
                          ? const Color(0xFF007AFF)
                          : visual.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Control Humano',
                      style: TextStyle(
                        color: _isHumanOwned
                            ? const Color(0xFF007AFF)
                            : visual.textMuted,
                        fontFamily: 'Inter',
                        fontFamilyFallback: ConversationDetailSheet._sfFallback,
                        fontSize: 13,
                        fontWeight: _isHumanOwned
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLastMessage(AutomationVisualPalette visual) {
    // Si no hay mensaje real previo, renderizar estado enriquecido de nuevo chat
    final lastMsg = widget.item.lastMessage.trim();
    final isPhoneNumber = RegExp(r'^\+?[0-9\s\-]+$').hasMatch(lastMsg);
    if (lastMsg.isEmpty || isPhoneNumber) {
      return _buildNewChatEmptyState(visual);
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: visual.isDark ? 0.08 : 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: visual.isDark ? 0.15 : 0.60),
                width: 0.8,
              ),
            ),
            child: Text(
              'Historial reciente de mensajes',
              style: TextStyle(
                color: visual.textMuted,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildChatBubble(widget.item.lastMessage, true, visual),
        if (widget.item.hasPendingReply && widget.item.pendingReplyText != null)
          _buildChatBubble(widget.item.pendingReplyText!, false, visual),
      ],
    );
  }

  Widget _buildNewChatEmptyState(AutomationVisualPalette visual) {
    final title = _cleanName(widget.item.displayName);
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF25D366).withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF25D366)),
                SizedBox(width: 6),
                Text(
                  'Chat directo cifrado vía WhatsApp',
                  style: TextStyle(
                    color: Color(0xFF25D366),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : 'W',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            title,
            style: TextStyle(
              color: visual.text,
              fontSize: 17.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            widget.item.lastMessage.isNotEmpty ? widget.item.lastMessage : widget.item.conversationId,
            style: TextStyle(
              color: visual.textMuted,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: visual.isDark ? 0.05 : 0.60),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: visual.isDark ? 0.12 : 0.40),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Iniciar conversación rápida:',
                style: TextStyle(
                  color: visual.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickStarterChip('👋 ¡Hola! ¿Cómo estás?', visual),
                  _buildQuickStarterChip('💼 Buenas tardes, ¿en qué podemos ayudarte?', visual),
                  _buildQuickStarterChip('📋 Enviar formulario interactivo', visual, isForm: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStarterChip(String label, AutomationVisualPalette visual, {bool isForm = false}) {
    return ActionChip(
      avatar: Icon(
        isForm ? Icons.assignment_rounded : Icons.chat_bubble_outline_rounded,
        size: 13,
        color: isForm ? const Color(0xFF00FF88) : const Color(0xFF007AFF),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: visual.text,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: Colors.white.withValues(alpha: visual.isDark ? 0.08 : 0.8),
      side: BorderSide(
        color: isForm
            ? const Color(0xFF00FF88).withValues(alpha: 0.4)
            : const Color(0xFF007AFF).withValues(alpha: 0.4),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        if (isForm) {
          _showFormPicker();
        } else {
          _safeSetState(() {
            _inputController.text = label.replaceFirst('👋 ', '').replaceFirst('💼 ', '');
          });
        }
      },
    );
  }

  Widget _buildChatBubble(
    String text,
    bool isInbound,
    AutomationVisualPalette visual,
  ) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isInbound ? 5 : 22),
      bottomRight: Radius.circular(isInbound ? 22 : 5),
    );

    return Align(
      alignment: isInbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: isInbound
                  ? Colors.black.withValues(alpha: visual.isDark ? 0.25 : 0.06)
                  : const Color(0xFF007AFF).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: isInbound
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: visual.isDark
                            ? [
                                Colors.white.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0.05),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.85),
                                Colors.white.withValues(alpha: 0.65),
                              ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xDD007AFF),
                          Color(0xB30056C6),
                        ],
                      ),
                border: Border.all(
                  color: isInbound
                      ? (visual.isDark
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.70))
                      : Colors.white.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isInbound ? visual.text : Colors.white,
                  fontFamily: 'Inter',
                  fontFamilyFallback: ConversationDetailSheet._sfFallback,
                  fontSize: 14.5,
                  height: 1.38,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(AutomationVisualPalette visual) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            14,
            10,
            14,
            MediaQuery.of(context).viewInsets.bottom + 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: visual.isDark ? 0.04 : 0.40),
            border: Border(
              top: BorderSide(
                color: visual.isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0x33CBD5E1),
                width: 0.8,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _generateAiSuggestion,
                icon: const Icon(CupertinoIcons.sparkles, size: 14),
                label: const Text(
                  'Sugerir con IA',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: ConversationDetailSheet._sfFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF),
                  side: BorderSide(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.45),
                  ),
                  backgroundColor: const Color(
                    0xFF007AFF,
                  ).withValues(alpha: 0.10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final text = _suggestions[index];
                  final isSelected =
                      _inputController.text.trim() == text.trim();
                  return ActionChip(
                    avatar: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.chat_bubble_outline_rounded,
                      size: 13,
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : visual.textMuted,
                    ),
                    label: Text(
                      'Opción ${index + 1}: ${text.length > 28 ? "${text.substring(0, 28)}..." : text}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: ConversationDetailSheet._sfFallback,
                        fontSize: 11.5,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF007AFF)
                            : visual.text,
                      ),
                    ),
                    backgroundColor: isSelected
                        ? const Color(0xFF007AFF).withValues(alpha: 0.14)
                        : (visual.isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.04)),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF007AFF).withValues(alpha: 0.50)
                          : (visual.isDark ? Colors.white12 : Colors.black12),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () {
                      _safeSetState(() {
                        _inputController.text = text;
                      });
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: _busy ? null : _showAttachmentMenu,
                tooltip: 'Adjuntar documento, imagen, PDF o formulario',
                icon: Icon(
                  CupertinoIcons.paperclip,
                  color: visual.accent,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: visual.accent.withValues(alpha: 0.12),
                  padding: const EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: !_busy,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(
                    color: visual.text,
                    fontFamily: 'Inter',
                    fontFamilyFallback: ConversationDetailSheet._sfFallback,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Escribe tu respuesta...',
                    hintStyle: TextStyle(
                      color: visual.textMuted,
                      fontFamily: 'Inter',
                      fontFamilyFallback: ConversationDetailSheet._sfFallback,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(
                      alpha: visual.isDark ? 0.08 : 0.85,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(
                          alpha: visual.isDark ? 0.18 : 0.50,
                        ),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                        color: Color(0xFF007AFF),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _busy ? null : _sendReply,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF007AFF), Color(0xFF0056C6)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.arrow_up,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    ),
    );
  }
}
