import 'package:flutter/material.dart';

import 'nano_ambient_background.dart';

/// Shell compartido de las pantallas Chat y Modelos.
///
/// Identidad visual de la pantalla Inicio: fondo azul marino casi negro con
/// reflejos ambientales, header con marca pequeña `nanoai` + título grande,
/// sin AppBar tradicional ni menú inferior.
class NanoScreenShell extends StatelessWidget {
  const NanoScreenShell({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
  });

  final String title;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020611),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: NanoAmbientBackground()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'nanoai',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 19,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                height: 1,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

