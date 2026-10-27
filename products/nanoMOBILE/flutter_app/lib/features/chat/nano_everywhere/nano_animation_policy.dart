import 'package:flutter/widgets.dart';

/// Shares visibility and accessibility policy without changing animation timing.
/// Owners settle their controllers in [onMotionPolicyChanged] when disabled.
mixin NanoAnimationPolicy<T extends StatefulWidget> on State<T> {
  late final AppLifecycleListener _motionLifecycle;
  bool motionEnabled = false;
  bool _motionForeground = true;

  /// Observes foreground changes; dependencies supply route and user policy.
  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _motionForeground = state == null || state == AppLifecycleState.resumed;
    _motionLifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _motionForeground = state == AppLifecycleState.resumed;
        if (mounted) setState(_syncMotionPolicy);
      },
    );
  }

  /// Re-evaluates when TickerMode or the system animation preference changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionPolicy();
  }

  /// Notifies owners only on a policy change, preserving uninterrupted timing.
  void _syncMotionPolicy() {
    final enabled =
        _motionForeground &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (enabled == motionEnabled) return;
    motionEnabled = enabled;
    onMotionPolicyChanged();
  }

  /// Owners stop owned clocks and apply their final state when motion is off.
  void onMotionPolicyChanged() {}

  /// Releases the observer alongside the owning State.
  @override
  void dispose() {
    _motionLifecycle.dispose();
    super.dispose();
  }
}
