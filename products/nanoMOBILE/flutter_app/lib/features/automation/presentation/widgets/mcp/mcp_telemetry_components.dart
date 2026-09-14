import 'package:flutter/material.dart';

import '../../../engine/orchestration/execution_journal.dart';
import '../../automation_visual_theme.dart';

/// Tarjeta de registro de ejecución para la pestaña de telemetría.
class McpTelemetryLogCard extends StatelessWidget {
  const McpTelemetryLogCard({
    super.key,
    required this.entry,
    required this.visual,
  });

  final ExecutionJournalEntry entry;
  final AutomationVisualPalette visual;

  @override
  Widget build(BuildContext context) {
    final isSuccess = entry.status == ExecutionJournalStatus.verified ||
        entry.status == ExecutionJournalStatus.executed;
    final isPending = entry.status == ExecutionJournalStatus.executing ||
        entry.status == ExecutionJournalStatus.waitingConfirmation;
    final statusColor = isSuccess
        ? const Color(0xFF10B981)
        : isPending
            ? const Color(0xFF38BDF8)
            : const Color(0xFFEF4444);

    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: visual.cardStart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: visual.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: TextStyle(
                  color: visual.textMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.status.name.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.actionSignature.isNotEmpty
                ? entry.actionSignature
                : (entry.semanticAction.isNotEmpty ? entry.semanticAction : entry.stepId),
            style: TextStyle(
              color: visual.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          if (entry.verificationState.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.verificationState,
              style: TextStyle(
                color: visual.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
