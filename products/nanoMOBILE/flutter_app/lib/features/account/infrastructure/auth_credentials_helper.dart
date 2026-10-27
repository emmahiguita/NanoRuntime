import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Funciones auxiliares para derivación de hashes y UIDs deterministas en autenticación.
class AuthCredentialsHelper {
  const AuthCredentialsHelper._();

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static String deriveUserUid(String email) {
    final hash = sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
    return 'usr_${hash.substring(0, 24)}';
  }

  static String deriveGoogleUid(String email) {
    final hash = sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
    return 'goog_${hash.substring(0, 20)}';
  }

  static bool isValidEmail(String email) {
    final clean = email.trim().toLowerCase();
    return clean.contains('@') && clean.contains('.');
  }
}
