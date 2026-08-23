import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'action_ledger.dart';

/// Ledger compartido del módulo de automatización. Un único registro de
/// ejecuciones reales para todo el módulo (no por instancia de coordinator),
/// para que chat / notificaciones / voz / eventos futuros tracen al mismo
/// sitio. Se inyecta al [AutomationCoordinator].
final actionLedgerProvider = Provider<ActionLedger>((ref) => ActionLedger());
