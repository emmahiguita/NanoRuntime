import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/account_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/device_repository.dart';
import '../domain/donation_repository.dart';
import '../domain/subscription_repository.dart';
import '../infrastructure/device_management_adapter.dart';
import '../infrastructure/firebase_auth_adapter.dart';
import '../infrastructure/firestore_account_adapter.dart';
import '../infrastructure/google_play_billing_adapter.dart';
import '../infrastructure/voluntary_donation_adapter.dart';
import 'auth_controller.dart';
import 'device_controller.dart';
import 'donation_controller.dart';
import 'session_gate_controller.dart';
import 'subscription_controller.dart';

/// QUÉ HACE:
/// Registro oficial de proveedores de dependencias para el módulo de cuenta Nano.
///
/// CÓMO FUNCIONA:
/// Instancia los repositorios e inyecta los adaptadores correspondientes en los controladores.
///
/// POR QUÉ:
/// Permite reemplazar adaptadores en tests o entornos específicos sin tocar la UI.

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthAdapter();
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return FirestoreAccountAdapter();
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return GooglePlayBillingAdapter();
});

final donationRepositoryProvider = Provider<DonationRepository>((ref) {
  return VoluntaryDonationAdapter();
});

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceManagementAdapter();
});

final sessionGateProvider =
    StateNotifierProvider<SessionGateNotifier, AuthState>((ref) {
      final authRepo = ref.watch(authRepositoryProvider);
      final accountRepo = ref.watch(accountRepositoryProvider);
      return SessionGateNotifier(
        authRepository: authRepo,
        accountRepository: accountRepo,
      );
    });

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      final authRepo = ref.watch(authRepositoryProvider);
      final accountRepo = ref.watch(accountRepositoryProvider);
      return AuthController(authRepo, accountRepository: accountRepo);
    });

final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>((ref) {
      final subRepo = ref.watch(subscriptionRepositoryProvider);
      return SubscriptionController(subRepo);
    });

final donationControllerProvider =
    StateNotifierProvider<DonationController, DonationBannerState>((ref) {
      final donationRepo = ref.watch(donationRepositoryProvider);
      return DonationController(donationRepo);
    });

final deviceControllerProvider =
    StateNotifierProvider<DeviceController, DeviceListState>((ref) {
      final deviceRepo = ref.watch(deviceRepositoryProvider);
      final authState = ref.watch(sessionGateProvider);
      return DeviceController(
        repository: deviceRepo,
        uid: authState.user.uid,
      );
    });
