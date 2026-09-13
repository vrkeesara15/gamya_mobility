import 'package:flutter/material.dart';
import 'colors.dart';

class GamyaTheme {
  GamyaTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: GamyaColors.gold,
      onPrimary: Colors.white,
      secondary: GamyaColors.dark,
      onSecondary: Colors.white,
      error: GamyaColors.danger,
      onError: Colors.white,
      surface: GamyaColors.white,
      onSurface: GamyaColors.textPrimary,
      surfaceContainerHighest: GamyaColors.surface,
      outline: GamyaColors.border,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Roboto');
    return base.copyWith(
      scaffoldBackgroundColor: GamyaColors.surface,
      textTheme: base.textTheme.apply(bodyColor: GamyaColors.textPrimary, displayColor: GamyaColors.textPrimary),
      appBarTheme: const AppBarTheme(backgroundColor: GamyaColors.dark, foregroundColor: Colors.white, elevation: 0, centerTitle: false),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: GamyaColors.border))),
      dividerTheme: const DividerThemeData(color: GamyaColors.divider, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamyaColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamyaColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamyaColors.gold, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamyaColors.danger)),
        hintStyle: const TextStyle(color: GamyaColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: GamyaColors.textSecondary, fontSize: 14),
        prefixIconColor: GamyaColors.textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: GamyaColors.gold, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: GamyaColors.gold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: GamyaColors.textPrimary, side: const BorderSide(color: GamyaColors.border), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: GamyaColors.gold, textStyle: const TextStyle(fontWeight: FontWeight.w600))),
      chipTheme: ChipThemeData(backgroundColor: GamyaColors.neutralBg, side: BorderSide.none, labelStyle: const TextStyle(fontSize: 12, color: GamyaColors.textPrimary), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      tabBarTheme: const TabBarThemeData(labelColor: GamyaColors.gold, unselectedLabelColor: GamyaColors.textSecondary, indicatorColor: GamyaColors.gold, dividerColor: GamyaColors.border, labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13), unselectedLabelStyle: TextStyle(fontSize: 13)),
      dialogTheme: DialogThemeData(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: GamyaColors.dark),
      checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? GamyaColors.gold : Colors.white), side: const BorderSide(color: GamyaColors.textMuted)),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? GamyaColors.gold : GamyaColors.textMuted)),
      switchTheme: SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? GamyaColors.gold : Colors.white), trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? GamyaColors.goldLight : GamyaColors.border)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: GamyaColors.gold),
      dataTableTheme: const DataTableThemeData(headingRowColor: WidgetStatePropertyAll(GamyaColors.surface), headingTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GamyaColors.textSecondary), dataTextStyle: TextStyle(fontSize: 13, color: GamyaColors.textPrimary), dividerThickness: 1, horizontalMargin: 12, columnSpacing: 18),
      popupMenuTheme: PopupMenuThemeData(color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: GamyaColors.border)), textStyle: const TextStyle(fontSize: 13, color: GamyaColors.textPrimary)),
      dropdownMenuTheme: DropdownMenuThemeData(inputDecorationTheme: base.inputDecorationTheme),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)))),
    );
  }
}
