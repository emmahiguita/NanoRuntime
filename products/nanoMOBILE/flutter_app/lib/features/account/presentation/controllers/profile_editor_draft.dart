import 'package:flutter/material.dart';
import '../../domain/account_profile.dart';
import '../../domain/auth_user.dart';

/// Borrador de edición: posee los controladores y conserva datos reales vacíos.
/// No escribe en almacenamiento; la pantalla delega guardar al caso de uso existente.
class ProfileEditorDraft {
  final TextEditingController name, username, bio, country, region;
  final TextEditingController city, address, phone, email;
  String? photoPath;
  String? coverPath; // Solo UI: imagen de portada (no persiste aún en el modelo)
  DateTime? birthDate;
  String gender, language;

  ProfileEditorDraft(AccountProfile profile, AuthUser user)
    : name = TextEditingController(
        text: profile.displayName.isNotEmpty
            ? profile.displayName
            : user.displayName,
      ),
      username = TextEditingController(text: profile.username),
      bio = TextEditingController(text: profile.bio),
      country = TextEditingController(text: profile.country),
      region = TextEditingController(text: profile.stateProvince),
      city = TextEditingController(text: profile.city),
      address = TextEditingController(text: profile.address),
      phone = TextEditingController(text: profile.phone),
      email = TextEditingController(
        text: profile.email.isNotEmpty ? profile.email : user.email,
      ),
      photoPath = profile.photoUrl,
      coverPath = profile.coverUrl,
      birthDate = profile.birthDate,
      gender = profile.gender,
      language = profile.language;

  /// Solo reemplaza campos editables; no cambia plan, UID ni permisos de cuenta.
  AccountProfile applyTo(AccountProfile profile) => profile.copyWith(
    displayName: name.text.trim(),
    username: username.text.trim(),
    bio: bio.text.trim(),
    country: country.text.trim(),
    stateProvince: region.text.trim(),
    city: city.text.trim(),
    address: address.text.trim(),
    phone: phone.text.trim(),
    email: email.text.trim(),
    photoUrl: photoPath,
    clearPhoto: photoPath == null,
    coverUrl: coverPath,
    clearCover: coverPath == null,
    birthDate: birthDate,
    gender: gender,
    language: language,
  );

  /// Libera únicamente los recursos que este borrador creó.
  void dispose() {
    for (final controller in [
      name,
      username,
      bio,
      country,
      region,
      city,
      address,
      phone,
      email,
    ]) {
      controller.dispose();
    }
  }
}
