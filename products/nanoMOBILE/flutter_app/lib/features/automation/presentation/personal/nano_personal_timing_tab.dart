import 'package:flutter/material.dart';
import '../widgets/whatsapp_reply_delay_card.dart';
import 'nano_personal_quiet_hours_card.dart';

/// Cada control aquí guarda una preferencia consumida por el pipeline de envío.
class NanoPersonalTimingTab extends StatelessWidget {
  const NanoPersonalTimingTab({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    children: const [
      WhatsAppReplyDelayCard(),
      SizedBox(height: 12),
      NanoPersonalQuietHoursCard(),
    ],
  );
}
