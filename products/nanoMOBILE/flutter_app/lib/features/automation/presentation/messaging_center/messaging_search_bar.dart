import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/messaging_platform.dart';
import 'messaging_center_providers.dart';

/// Búsqueda iOS estable: una sola superficie, sin saltos ni controles flotantes.
class MessagingSearchBar extends ConsumerStatefulWidget {
  const MessagingSearchBar({super.key});

  @override
  ConsumerState<MessagingSearchBar> createState() => _MessagingSearchBarState();
}

class _MessagingSearchBarState extends ConsumerState<MessagingSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(messagingSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeFilter = ref.watch(selectedCategoryTabProvider);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF526276);
    return Container(
      height: 44,
      decoration: _glassDecoration(isDark),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          ref.read(messagingSearchQueryProvider.notifier).state = value;
          setState(() {});
        },
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF172033),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar personas o conversaciones',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF7C8A9C),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF288BC7),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          suffixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Limpiar búsqueda',
                  icon: const Icon(Icons.close_rounded, size: 17),
                  color: iconColor,
                  onPressed: () {
                    _controller.clear();
                    ref.read(messagingSearchQueryProvider.notifier).state = '';
                    setState(() {});
                  },
                ),
              _buildFilterMenu(iconColor, activeFilter),
              const SizedBox(width: 3),
            ],
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterMenu(
    Color iconColor,
    MessagingCategoryFilter activeFilter,
  ) => PopupMenuButton<MessagingCategoryFilter>(
    tooltip: 'Filtrar conversaciones',
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
    icon: Icon(
      Icons.tune_rounded,
      size: 18,
      color: activeFilter != MessagingCategoryFilter.all
          ? const Color(0xFF288BC7)
          : iconColor,
    ),
    onSelected: (category) =>
        ref.read(selectedCategoryTabProvider.notifier).state = category,
    itemBuilder: (context) => [
      _item(
        MessagingCategoryFilter.all,
        'Todos',
        Icons.forum_rounded,
        activeFilter,
      ),
      _item(
        MessagingCategoryFilter.unread,
        'No leídos',
        Icons.mark_chat_unread_rounded,
        activeFilter,
      ),
      _item(
        MessagingCategoryFilter.groups,
        'Grupos',
        Icons.groups_rounded,
        activeFilter,
      ),
      _item(
        MessagingCategoryFilter.personal,
        'Agente Personal',
        Icons.person_rounded,
        activeFilter,
      ),
      _item(
        MessagingCategoryFilter.business,
        'Agente Negocios',
        Icons.business_center_rounded,
        activeFilter,
      ),
      _item(
        MessagingCategoryFilter.archived,
        'Archivados',
        Icons.archive_rounded,
        activeFilter,
      ),
    ],
  );

  PopupMenuItem<MessagingCategoryFilter> _item(
    MessagingCategoryFilter value,
    String label,
    IconData icon,
    MessagingCategoryFilter current,
  ) {
    final selected = value == current;
    return PopupMenuItem(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: selected ? const Color(0xFF288BC7) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _glassDecoration(bool isDark) => BoxDecoration(
    color: isDark
        ? const Color(0xFF172033).withValues(alpha: 0.58)
        : Colors.white.withValues(alpha: 0.47),
    borderRadius: BorderRadius.circular(15),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.68),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.055),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}
