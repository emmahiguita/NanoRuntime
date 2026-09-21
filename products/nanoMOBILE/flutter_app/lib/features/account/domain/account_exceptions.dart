/// QUÉ HACE:
/// Define las excepciones tipadas del dominio de cuenta y autenticación en Nano.
///
/// CÓMO FUNCIONA:
/// Cada excepción hereda de [AccountException] y encapsula un mensaje comprensible
/// para el usuario, sanitizando detalles técnicos de red o códigos internos de Firebase.
///
/// POR QUÉ:
/// Regla 29 del sistema: no exponer cadenas técnicas como "firebase_auth/user-not-found"
/// o "PlatformException" en la interfaz de usuario, garantizando UX premium.
abstract class AccountException implements Exception {
  final String message;
  final String? technicalCode;

  const AccountException(this.message, [this.technicalCode]);

  @override
  String toString() => message;
}

class InvalidCredentialsException extends AccountException {
  const InvalidCredentialsException([String? code])
    : super('Correo o contraseña incorrectos. Verifica tus datos.', code);
}

class EmailAlreadyInUseException extends AccountException {
  const EmailAlreadyInUseException([String? code])
    : super('Este correo ya está registrado con otra cuenta.', code);
}

class WeakPasswordException extends AccountException {
  const WeakPasswordException([String? code])
    : super('La contraseña debe tener al menos 8 caracteres.', code);
}

class NetworkUnavailableException extends AccountException {
  const NetworkUnavailableException([String? code])
    : super('Sin conexión a Internet. Operando en modo local.', code);
}

class AccountDisabledException extends AccountException {
  const AccountDisabledException([String? code])
    : super('Esta cuenta ha sido inhabilitada. Contacta a soporte.', code);
}

class EmailNotVerifiedException extends AccountException {
  const EmailNotVerifiedException([String? code])
    : super('Debes verificar tu correo antes de continuar.', code);
}

class UserNotFoundException extends AccountException {
  const UserNotFoundException([String? code])
    : super('No se encontró una cuenta con este correo.', code);
}

class AccountDeletionFailedException extends AccountException {
  const AccountDeletionFailedException([String? message, String? code])
    : super(message ?? 'No se pudo eliminar la cuenta. Reintenta.', code);
}

class ReauthenticationRequiredException extends AccountException {
  const ReauthenticationRequiredException([String? code])
    : super('Por seguridad, vuelve a iniciar sesión antes de esta acción.', code);
}

class BillingUnavailableException extends AccountException {
  const BillingUnavailableException([String? code])
    : super('Google Play Billing no está disponible en este momento.', code);
}

class PurchasePendingException extends AccountException {
  const PurchasePendingException([String? code])
    : super('Tu compra está pendiente de confirmación por la tienda.', code);
}

class PurchaseCancelledException extends AccountException {
  const PurchaseCancelledException([String? code])
    : super('Operación de compra cancelada.', code);
}

class EntitlementVerificationException extends AccountException {
  const EntitlementVerificationException([String? code])
    : super('No se pudo verificar la validez de la suscripción.', code);
}
