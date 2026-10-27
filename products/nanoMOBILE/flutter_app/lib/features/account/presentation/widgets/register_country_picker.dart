import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

class CountryInfo {
  final String code;
  final String name;
  final String dialCode;
  final String flag;

  const CountryInfo({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
  });
}

const List<CountryInfo> kNanoCountries = [
  CountryInfo(code: 'CO', name: 'Colombia', dialCode: '+57', flag: '🇨🇴'),
  CountryInfo(code: 'MX', name: 'México', dialCode: '+52', flag: '🇲🇽'),
  CountryInfo(code: 'ES', name: 'España', dialCode: '+34', flag: '🇪🇸'),
  CountryInfo(code: 'US', name: 'Estados Unidos', dialCode: '+1', flag: '🇺🇸'),
  CountryInfo(code: 'AR', name: 'Argentina', dialCode: '+54', flag: '🇦🇷'),
  CountryInfo(code: 'CL', name: 'Chile', dialCode: '+56', flag: '🇨🇱'),
  CountryInfo(code: 'PE', name: 'Perú', dialCode: '+51', flag: '🇵🇪'),
  CountryInfo(code: 'EC', name: 'Ecuador', dialCode: '+593', flag: '🇪🇨'),
  CountryInfo(code: 'VE', name: 'Venezuela', dialCode: '+58', flag: '🇻🇪'),
  CountryInfo(code: 'BR', name: 'Brasil', dialCode: '+55', flag: '🇧🇷'),
  CountryInfo(code: 'PA', name: 'Panamá', dialCode: '+507', flag: '🇵🇦'),
  CountryInfo(code: 'CR', name: 'Costa Rica', dialCode: '+506', flag: '🇨🇷'),
  CountryInfo(
    code: 'DO',
    name: 'República Dominicana',
    dialCode: '+1',
    flag: '🇩🇴',
  ),
  CountryInfo(code: 'GT', name: 'Guatemala', dialCode: '+502', flag: '🇬🇹'),
  CountryInfo(code: 'BO', name: 'Bolivia', dialCode: '+591', flag: '🇧🇴'),
  CountryInfo(code: 'UY', name: 'Uruguay', dialCode: '+598', flag: '🇺🇾'),
  CountryInfo(code: 'PY', name: 'Paraguay', dialCode: '+595', flag: '🇵🇾'),
];

void showNanoCountryPicker({
  required BuildContext context,
  required NanoColors colors,
  required ValueChanged<CountryInfo> onSelected,
}) {
  showNanoGlassWindow(
    context: context,
    builder: (ctx) {
      return SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NanoSpacing.md,
                4,
                NanoSpacing.md,
                NanoSpacing.sm,
              ),
              child: Text(
                'Selecciona tu País',
                style: NanoType.headline(colors.onSurface),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: kNanoCountries.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.12),
                ),
                itemBuilder: (ctx, i) {
                  final country = kNanoCountries[i];
                  return ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      country.name,
                      style: NanoType.body(colors.onSurface),
                    ),
                    trailing: Text(
                      country.dialCode,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      onSelected(country);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
