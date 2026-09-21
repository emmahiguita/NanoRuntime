import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/donation_repository.dart';

/// QUÉ HACE:
/// Controla la visualización respetuosa del banner de apoyo voluntario.
///
/// CÓMO FUNCIONA:
/// Comprueba si han transcurrido los días de cooldown y si el banner no ha
/// sido descartado recientemente. Permite descartarlo temporalmente con "Ahora no".
///
/// POR QUÉ:
/// Evita conductas intrusivas (popups molestos) y asegura que el aporte sea
/// 100% voluntario y discreto.
class DonationBannerState {
  final bool shouldShow;
  final bool isInteracting;

  const DonationBannerState({
    this.shouldShow = false,
    this.isInteracting = false,
  });

  DonationBannerState copyWith({bool? shouldShow, bool? isInteracting}) {
    return DonationBannerState(
      shouldShow: shouldShow ?? this.shouldShow,
      isInteracting: isInteracting ?? this.isInteracting,
    );
  }
}

class DonationController extends StateNotifier<DonationBannerState> {
  final DonationRepository _repository;

  DonationController(this._repository) : super(const DonationBannerState()) {
    checkBannerVisibility();
  }

  Future<void> checkBannerVisibility() async {
    final canShow = await _repository.shouldShowSupportBanner();
    state = state.copyWith(shouldShow: canShow);
  }

  Future<void> dismissBanner() async {
    state = state.copyWith(shouldShow: false);
    await _repository.recordBannerDismissed();
  }

  Future<bool> triggerSupportAction() async {
    state = state.copyWith(isInteracting: true);
    final launched = await _repository.launchVoluntaryDonationFlow();
    state = state.copyWith(isInteracting: false, shouldShow: false);
    return launched;
  }
}
