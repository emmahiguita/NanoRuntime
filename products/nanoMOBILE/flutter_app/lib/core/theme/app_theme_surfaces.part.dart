part of 'app_theme.dart';

/// Superficies y ventanas: colores semánticos sin un segundo tema.
ThemeData _nanoThemeSurfaces(ThemeData base, NanoColors c, bool isDark) =>
    base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? c.surface : c.backgroundElevated,
        surfaceTintColor: isDark ? Colors.transparent : c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: NanoShapes.large,
          side: BorderSide(
            color: isDark ? Colors.transparent : c.outline,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 3,
        backgroundColor: isDark ? c.background : c.backgroundElevated,
        surfaceTintColor: isDark ? Colors.transparent : c.primary,
        titleTextStyle: _nanoTextTheme.titleMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: c.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? c.surfaceVariant.withValues(alpha: 0.5)
            : c.backgroundElevated,
        indicatorColor: c.primaryContainer,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.primary);
          }
          return IconThemeData(color: c.onSurfaceVariant);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: c.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.onSurfaceVariant,
        textColor: c.onSurface,
        tileColor: Colors.transparent,
        selectedTileColor: c.primaryContainer.withValues(alpha: 0.3),
        selectedColor: c.primary,
        shape: const RoundedRectangleBorder(borderRadius: NanoShapes.medium),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? c.surfaceVariant : c.glassSurface,
        selectedColor: c.primaryContainer,
        labelStyle: TextStyle(color: c.onSurface, fontWeight: FontWeight.w500),
        side: BorderSide(color: isDark ? Colors.transparent : c.glassBorder),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.surface : c.backgroundElevated,
        contentTextStyle: TextStyle(
          color: c.onSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: NanoShapes.medium,
          side: BorderSide(color: isDark ? Colors.transparent : c.outline),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? c.surface : c.backgroundElevated,
        surfaceTintColor: isDark ? Colors.transparent : c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: NanoShapes.large,
          side: BorderSide(color: isDark ? Colors.transparent : c.outline),
        ),
        elevation: 4,
        titleTextStyle: TextStyle(
          color: c.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 24, // Expressive typography
        ),
        contentTextStyle: TextStyle(color: c.onSurfaceVariant, fontSize: 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? c.surface : c.backgroundElevated,
        surfaceTintColor: isDark ? Colors.transparent : c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
          ), // Very organic top corners
          side: BorderSide(color: isDark ? Colors.transparent : c.outline),
        ),
        elevation: 2,
      ),
    );
