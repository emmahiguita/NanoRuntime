import 'package:flutter/material.dart';

/// Teclas PTY reales. Una fila desplazable sustituye las dos filas permanentes.
class TerminalKeysRow extends StatelessWidget {
  const TerminalKeysRow({super.key, required this.onWriteBytes});
  final ValueChanged<List<int>> onWriteBytes;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final key in <(String, List<int>)>[
            ('Ctrl+C', [3]),
            ('Esc', [27]),
            ('Tab', [9]),
            ('↑', [27, 91, 65]),
            ('↓', [27, 91, 66]),
            ('←', [27, 91, 68]),
            ('→', [27, 91, 67]),
            ('Ctrl+D', [4]),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
                onPressed: () => onWriteBytes(key.$2),
                child: Text(key.$1),
              ),
            ),
        ],
      ),
    ),
  );
}
