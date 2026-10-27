import 'package:flutter/material.dart';

/// Fecha y edad reales: no atribuye una fecha de nacimiento al usuario.
class ProfileBirthDateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const ProfileBirthDateField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Ajusta datos antiguos al rango inicial para evitar assertions del calendario.
  Future<void> _choose(BuildContext context) async {
    final first = DateTime(1920);
    final last = DateUtils.dateOnly(DateTime.now());
    final stored = value == null ? last : DateUtils.dateOnly(value!);
    final initial = stored.isBefore(first)
        ? first
        : stored.isAfter(last)
        ? last
        : stored;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (context.mounted && picked != null) onChanged(picked);
  }

  /// Recalcula edad; no persiste un número que se volvería obsoleto.
  @override
  Widget build(BuildContext context) {
    String description = 'Sin especificar';
    if (value != null) {
      final date = value!;
      final now = DateTime.now();
      var age = now.year - date.year;
      if (now.month < date.month ||
          (now.month == date.month && now.day < date.day)) {
        age--;
      }
      description = MaterialLocalizations.of(context).formatMediumDate(date);
      if (age >= 0) description += ' · $age años';
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cake_outlined),
      title: const Text('Fecha de nacimiento'),
      subtitle: Text(description),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: () => _choose(context),
    );
  }
}
