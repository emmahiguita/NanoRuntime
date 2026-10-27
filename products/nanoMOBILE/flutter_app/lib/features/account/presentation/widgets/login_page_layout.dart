import 'package:flutter/material.dart';
import 'login_auth_header.dart';

/// QUÉ: distribuye marca y acceso según el espacio real.
/// CÓMO: dos columnas desde 760 px; una columna en teléfono o con teclado.
/// POR QUÉ: limitar el ancho y permitir scroll evita campos cortados en horizontal.
class LoginPageLayout extends StatelessWidget {
  const LoginPageLayout({super.key, required this.form, required this.footer});
  final Widget form, footer;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final wide = size.maxWidth >= 760;
      final padding = size.maxWidth < 360 ? 20.0 : 28.0;
      final access = Column(
        mainAxisSize: MainAxisSize.min,
        children: [form, const SizedBox(height: 16), footer],
      );
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (size.maxHeight - padding * 2).clamp(0, double.infinity),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 880 : 420),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: LoginAuthHeader(isLandscape: true),
                        ),
                        const SizedBox(width: 64),
                        Expanded(child: access),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const LoginAuthHeader(isLandscape: false),
                        const SizedBox(height: 18),
                        access,
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}
