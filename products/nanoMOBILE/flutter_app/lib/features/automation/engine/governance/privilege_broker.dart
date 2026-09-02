/// PrivilegeBroker (A11) — resuelve el privilegio técnico MÍNIMO para ejecutar
/// un candidato. NO autoriza intención (eso es el firewall); solo mapea
/// capability → tier → disponibilidad.
///
/// Presencia en el enum != implementado != habilitado != autorizado.
library;

import '../planning/candidates/candidate_action.dart';
import '../privilege/shizuku_availability.dart';
import '../system/system_capability.dart';
import '../system/system_graph.dart';

enum PrivilegeTier {
  publicAndroid,
  notificationAccess,
  accessibility,
  mediaProjection,
  nanoLinux,
  developerAdb,
  shizuku,
  deviceOwner,
  rootLab,
}

class PrivilegeDecision {
  final PrivilegeTier tier;
  final bool available;
  final String reason;

  const PrivilegeDecision({
    required this.tier,
    required this.available,
    required this.reason,
  });
}

class PrivilegeBroker {
  const PrivilegeBroker();

  PrivilegeDecision resolve(
    CandidateAction candidate, {
    SystemGraph? graph,
    ShizukuAvailability? shizuku,
  }) {
    final tier = _minimumTier(candidate);
    final available = _available(tier, graph, shizuku);
    return PrivilegeDecision(
      tier: tier,
      available: available,
      reason: available
          ? 'Privilegio ${tier.name} disponible.'
          : 'Privilegio ${tier.name} no disponible.',
    );
  }

  /// Menor privilegio capaz de ejecutar el candidato.
  PrivilegeTier _minimumTier(CandidateAction c) {
    if (c.requiredCapabilities.contains(SystemCapability.shizuku)) {
      return PrivilegeTier.shizuku;
    }
    if (c.requiredCapabilities.contains(SystemCapability.root)) {
      return PrivilegeTier.rootLab;
    }
    if (c.requiredCapabilities.contains(SystemCapability.developerAdb)) {
      return PrivilegeTier.developerAdb;
    }
    if (c.requiredCapabilities.contains(SystemCapability.deviceOwner)) {
      return PrivilegeTier.deviceOwner;
    }
    if (c.requiredCapabilities.contains(SystemCapability.mediaProjection)) {
      return PrivilegeTier.mediaProjection;
    }
    if (c.tool.startsWith('linux.')) return PrivilegeTier.nanoLinux;
    if (c.tool == 'reply_notification' || c.tool == 'notifications') {
      return PrivilegeTier.notificationAccess;
    }
    if (c.requiredCapabilities.contains(
          SystemCapability.interactAccessibility,
        ) ||
        c.requiredCapabilities.contains(
          SystemCapability.observeAccessibility,
        ) ||
        c.requiredCapabilities.contains(SystemCapability.globalBack) ||
        c.requiredCapabilities.contains(SystemCapability.globalHome) ||
        c.requiredCapabilities.contains(SystemCapability.openNotifications) ||
        c.channel == ActionChannel.accessibility) {
      return PrivilegeTier.accessibility;
    }
    return PrivilegeTier.publicAndroid;
  }

  bool _available(
    PrivilegeTier tier,
    SystemGraph? graph,
    ShizukuAvailability? shizuku,
  ) {
    if (graph == null) {
      // Sin SystemGraph, solo publicAndroid es "disponible" (conservador).
      if (tier == PrivilegeTier.publicAndroid) return true;
      // Shizuku: disponibilidad factual del provider (null → unavailable).
      if (tier == PrivilegeTier.shizuku) return shizuku?.isAvailable ?? false;
      return false;
    }
    return switch (tier) {
      PrivilegeTier.publicAndroid => true,
      PrivilegeTier.notificationAccess =>
        graph.availabilityOf(SystemCapability.readNotifications).isAvailable ||
            graph
                .availabilityOf(SystemCapability.replyNotifications)
                .isAvailable,
      PrivilegeTier.accessibility =>
        graph
                .availabilityOf(SystemCapability.interactAccessibility)
                .isAvailable ||
            graph
                .availabilityOf(SystemCapability.observeAccessibility)
                .isAvailable,
      PrivilegeTier.nanoLinux =>
        graph.availabilityOf(SystemCapability.linuxExecution).isAvailable,
      PrivilegeTier.shizuku => shizuku?.isAvailable ?? false,
      _ => false, // mediaProjection/developerAdb/deviceOwner/rootLab
    };
  }
}
