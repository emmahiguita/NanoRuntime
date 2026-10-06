import 'package:flutter/material.dart';
import 'nano_glass_field.dart';

/// Ubicación opcional; los datos vacíos no atribuyen una residencia al usuario.
class ProfileLocationFields extends StatelessWidget {
  final TextEditingController countryController, stateController;
  final TextEditingController cityController, addressController;
  const ProfileLocationFields({
    super.key,
    required this.countryController,
    required this.stateController,
    required this.cityController,
    required this.addressController,
  });

  /// Una columna mantiene legibles los campos dentro de medias pantallas.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Ubicación', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      NanoGlassField(
        controller: countryController,
        label: 'País',
        prefixIcon: Icons.public_rounded,
      ),
      const SizedBox(height: 16),
      NanoGlassField(
        controller: stateController,
        label: 'Estado o departamento',
        prefixIcon: Icons.map_outlined,
      ),
      const SizedBox(height: 16),
      NanoGlassField(
        controller: cityController,
        label: 'Ciudad',
        prefixIcon: Icons.location_city_rounded,
      ),
      const SizedBox(height: 16),
      NanoGlassField(
        controller: addressController,
        label: 'Dirección',
        prefixIcon: Icons.home_outlined,
        textInputAction: TextInputAction.done,
      ),
    ],
  );
}
