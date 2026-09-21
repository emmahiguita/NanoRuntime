part of 'conversation_detail_sheet.dart';

/// [ConversationDetailEmptyView]
///
/// QUÉ HACE:
/// Renderiza la pantalla inicial para chats nuevos o conversaciones sin historial previo,
/// adaptándose a orientaciones vertical y horizontal para evitar desbordamientos.
///
/// CÓMO FUNCIONA:
/// 1. Muestra un badge de seguridad cifrada de WhatsApp.
/// 2. Avatar centrado con inicial del contacto.
/// 3. Chips de inicio rápido ("Hola", "Buenas tardes", "Enviar formulario interactivo").
/// 4. En horizontal (landscape), ajusta el tamaño del avatar y espaciados para mantener
///    la composición compacta, nítida y 100% visible.
///
/// POR QUÉ:
/// Garantiza una experiencia intuitiva para iniciar conversaciones con cualquier contacto
/// de WhatsApp sin exceder el límite de 200 líneas.
extension ConversationDetailEmptyView on _ConversationDetailSheetState {
  Widget _buildNewChatEmptyState(AutomationVisualPalette visual) {
    final title = _cleanName(widget.item.displayName);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isLandscape ? 10 : 20),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.35), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF25D366)),
                SizedBox(width: 6),
                Text(
                  'Chat directo cifrado vía WhatsApp',
                  style: TextStyle(color: Color(0xFF25D366), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isLandscape ? 10 : 18),
        Center(
          child: Container(
            width: isLandscape ? 46 : 64,
            height: isLandscape ? 46 : 64,
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
                  blurRadius: isLandscape ? 10 : 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : 'W',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLandscape ? 18 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            title,
            style: TextStyle(
              color: visual.text,
              fontSize: isLandscape ? 15 : 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            widget.item.lastMessage.isNotEmpty ? widget.item.lastMessage : widget.item.conversationId,
            style: TextStyle(color: visual.textMuted, fontSize: 12),
          ),
        ),
        SizedBox(height: isLandscape ? 12 : 18),
        Container(
          padding: EdgeInsets.all(isLandscape ? 10 : 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: visual.isDark ? 0.05 : 0.60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: visual.isDark ? 0.12 : 0.40), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Iniciar conversación rápida:',
                style: TextStyle(color: visual.text, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
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
      label: Text(label, style: TextStyle(color: visual.text, fontSize: 11, fontWeight: FontWeight.w500)),
      backgroundColor: Colors.white.withValues(alpha: visual.isDark ? 0.08 : 0.8),
      side: BorderSide(
        color: isForm ? const Color(0xFF00FF88).withValues(alpha: 0.4) : const Color(0xFF007AFF).withValues(alpha: 0.4),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
}
