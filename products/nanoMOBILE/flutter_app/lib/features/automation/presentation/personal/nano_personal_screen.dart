/// NANO-PERSONAL-SCREEN — Pantalla unificada y estudio completo de Nano Personal.
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/navigation/nano_navigation_panel.dart';
import '../automation_visual_theme.dart';
import 'nano_personal_channels_tab.dart';
import 'nano_personal_contacts_tab.dart';
import 'nano_personal_header.dart';
import 'nano_personal_identity_tab.dart';
import 'nano_personal_memory_tab.dart';
import 'nano_personal_phrases_tab.dart';
import 'nano_personal_timing_tab.dart';

class NanoPersonalScreen extends StatelessWidget {
  final int initialTabIndex;

  const NanoPersonalScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return DefaultTabController(
      length: 6,
      initialIndex: initialTabIndex,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: NanoShellBarScope(
          slotId: 'nano_personal',
          child: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                const AutomationBackHeader(),
                const NanoPersonalHeader(),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: visual.surface.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: visual.cardBorder.withValues(alpha: 0.15),
                    ),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: visual.accent,
                    labelColor: visual.accent,
                    unselectedLabelColor: visual.textMuted,
                    labelStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.forum_outlined, size: 18),
                        text: 'Frases y Diálogos',
                      ),
                      Tab(
                        icon: Icon(Icons.timer_outlined, size: 18),
                        text: 'Tiempos y Envío',
                      ),
                      Tab(
                        icon: Icon(Icons.psychology_outlined, size: 18),
                        text: 'Memorias',
                      ),
                      Tab(
                        icon: Icon(Icons.badge_outlined, size: 18),
                        text: 'Identidad',
                      ),
                      Tab(
                        icon: Icon(Icons.tune_rounded, size: 18),
                        text: 'Supervisión',
                      ),
                      Tab(
                        icon: Icon(Icons.people_outline, size: 18),
                        text: 'Contactos',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Expanded(
                  child: TabBarView(
                    children: [
                      NanoPersonalPhrasesTab(),
                      NanoPersonalTimingTab(),
                      NanoPersonalMemoryTab(),
                      NanoPersonalIdentityTab(),
                      NanoPersonalChannelsTab(),
                      NanoPersonalContactsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
