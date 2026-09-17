import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'messaging_center_providers.dart';

/// Barra de búsqueda con filtros avanzados y botón de micrófono por voz.
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
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x3D1E293B),
            Color(0x240F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onChanged: (val) {
          ref.read(messagingSearchQueryProvider.notifier).state = val;
        },
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Buscar conversaciones, personas o contenido...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12.5,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.5),
            size: 20,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: Colors.white70,
                  onPressed: () {
                    _controller.clear();
                    ref.read(messagingSearchQueryProvider.notifier).state = '';
                  },
                ),
              Icon(
                Icons.tune_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 19,
              ),
              const SizedBox(width: 12),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
