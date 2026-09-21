/// QUÉ HACE:
/// Modela el estado de suscripción de la cuenta Nano Mobile.
///
/// CÓMO FUNCIONA:
/// Define el plan activo, estado del ciclo de vida (activo, periodo de gracia,
/// cancelado, etc.) y los entitlements habilitados legítimamente.
///
/// POR QUÉ:
/// Separa la autoridad de facturación de la interfaz de usuario: la UI nunca
/// decide el plan arbitrariamente, sino que refleja el estado verificado.
enum SubscriptionTier { free, pro, business }

enum SubscriptionStatus {
  active,
  gracePeriod,
  pending,
  cancelled,
  expired,
  unknown,
}

class SubscriptionPlan {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? expiresAt;
  final bool willRenew;
  final List<String> entitlements;

  const SubscriptionPlan({
    required this.tier,
    required this.status,
    this.expiresAt,
    this.willRenew = false,
    this.entitlements = const [],
  });

  /// Plan predeterminado gratuito con capacidades base.
  static const SubscriptionPlan freeDefault = SubscriptionPlan(
    tier: SubscriptionTier.free,
    status: SubscriptionStatus.active,
    entitlements: ['local_ai_inference', 'terminal_shell', 'basic_tools'],
  );

  bool get isProOrHigher =>
      (tier == SubscriptionTier.pro || tier == SubscriptionTier.business) &&
      (status == SubscriptionStatus.active ||
          status == SubscriptionStatus.gracePeriod);

  bool get isBusiness =>
      tier == SubscriptionTier.business &&
      (status == SubscriptionStatus.active ||
          status == SubscriptionStatus.gracePeriod);

  SubscriptionPlan copyWith({
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    DateTime? expiresAt,
    bool? willRenew,
    List<String>? entitlements,
  }) {
    return SubscriptionPlan(
      tier: tier ?? this.tier,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      willRenew: willRenew ?? this.willRenew,
      entitlements: entitlements ?? this.entitlements,
    );
  }
}
