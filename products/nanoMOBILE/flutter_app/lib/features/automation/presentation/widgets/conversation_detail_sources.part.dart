part of 'conversation_detail_sheet.dart';

/// Distingue transportes observados, no confunde agente Personal con app instalada.
extension ConversationDetailSources on _ConversationDetailSheetState {
  bool get _hasWebSource => {
    widget.item.conversationId,
    ...widget.item.conversationAliases,
  }.any((id) => id.startsWith('waweb:'));

  bool get _hasAndroidSource =>
      !widget.item.conversationId.startsWith('waweb:') ||
      _activeNotification != null ||
      _historyIdForConversation() != null ||
      widget.item.conversationAliases.any((id) => id.startsWith('whatsapp/'));

  // Solo ofrece alternar si existe evidencia de ambas fuentes para este chat.
  Widget _buildCapabilityBadge(AutomationVisualPalette visual) {
    if (!_hasWebSource) return _buildAndroidCapabilityBadge(visual);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasAndroidSource)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Web'),
                  icon: Icon(Icons.language),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Instalado'),
                  icon: Icon(Icons.phone_android),
                ),
              ],
              selected: {_preferWebHistory},
              onSelectionChanged: (value) =>
                  setState(() => _preferWebHistory = value.first),
            )
          else
            const Text('WhatsApp Web · sesión vinculada'),
          if (!_preferWebHistory) _buildAndroidCapabilityBadge(visual),
        ],
      ),
    );
  }
}
