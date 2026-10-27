import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:yaru/yaru.dart' as yaru;

final _borderRadius = BorderRadius.circular(12);

/// Duck design tokens (Figma "Color" collection: Light / Dark / OLED).
const duckAccent = Color(0xFF1E6FD9);
const _cardRadius = 24.0;
const _sheetRadius = 28.0;

ColorScheme _duckScheme(Brightness brightness, {bool oled = false}) {
  if (brightness == Brightness.light) {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: duckAccent,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE3EDFB),
      onPrimaryContainer: Color(0xFF0B3A78),
      secondary: Color(0xFF5F5F66),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFEFEFF2),
      onSecondaryContainer: Color(0xFF111114),
      tertiary: Color(0xFF1E8E3E),
      onTertiary: Color(0xFFFFFFFF),
      error: Color(0xFFD93025),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFF6F6F8),
      onSurface: Color(0xFF111114),
      onSurfaceVariant: Color(0xFF5F5F66),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFFFFFF),
      surfaceContainer: Color(0xFFFFFFFF),
      surfaceContainerHigh: Color(0xFFEFEFF2),
      surfaceContainerHighest: Color(0xFFEFEFF2),
      outline: Color(0xFF9A9AA2),
      outlineVariant: Color(0xFFE2E2E6),
      surfaceTint: Colors.transparent,
    );
  }
  return ColorScheme(
    brightness: Brightness.dark,
    primary: const Color(0xFF4C8DF0),
    onPrimary: const Color(0xFF0A1B33),
    primaryContainer: oled ? const Color(0xFF122844) : const Color(0xFF16304F),
    onPrimaryContainer: const Color(0xFFCFE0FA),
    secondary: const Color(0xFFA4A4AC),
    onSecondary: const Color(0xFF101012),
    secondaryContainer: oled ? const Color(0xFF18181B) : const Color(0xFF242428),
    onSecondaryContainer: const Color(0xFFF2F2F4),
    tertiary: const Color(0xFF4CC26E),
    onTertiary: const Color(0xFF101012),
    error: const Color(0xFFF2675C),
    onError: const Color(0xFF101012),
    surface: oled ? const Color(0xFF000000) : const Color(0xFF101012),
    onSurface: const Color(0xFFF2F2F4),
    onSurfaceVariant: const Color(0xFFA4A4AC),
    surfaceContainerLowest: oled ? const Color(0xFF000000) : const Color(0xFF101012),
    surfaceContainerLow: oled ? const Color(0xFF0E0E10) : const Color(0xFF1A1A1D),
    surfaceContainer: oled ? const Color(0xFF0E0E10) : const Color(0xFF1A1A1D),
    surfaceContainerHigh: oled ? const Color(0xFF18181B) : const Color(0xFF242428),
    surfaceContainerHighest: oled ? const Color(0xFF18181B) : const Color(0xFF242428),
    outline: const Color(0xFF6E6E76),
    outlineVariant: oled ? const Color(0xFF242428) : const Color(0xFF2E2E33),
    surfaceTint: Colors.transparent,
  );
}

ThemeData getTheme(ColorMode colorMode, Color customColor, Brightness brightness, DynamicColors? dynamicColors) {
  if (colorMode == ColorMode.yaru) {
    return _getYaruTheme(brightness);
  }

  final colorScheme = _determineColorScheme(colorMode, customColor, brightness, dynamicColors);

  final inputBorder = OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: _borderRadius,
  );

  // https://github.com/localsend/localsend/issues/52
  final String fontFamily;
  if (checkPlatform([TargetPlatform.windows])) {
    fontFamily = switch (LocaleSettings.currentLocale) {
      AppLocale.ja => 'Yu Gothic UI',
      AppLocale.ko => 'Malgun Gothic',
      AppLocale.zhCn => 'Microsoft YaHei UI',
      AppLocale.zhHk || AppLocale.zhTw => 'Microsoft JhengHei UI',
      _ => 'Segoe UI Variable Display',
    };
  } else if (checkPlatform([TargetPlatform.linux])) {
    fontFamily = switch (LocaleSettings.currentLocale) {
      AppLocale.ja => 'Noto Sans CJK JP',
      AppLocale.ko => 'Noto Sans CJK KR',
      AppLocale.zhCn => 'Noto Sans CJK SC',
      AppLocale.zhHk || AppLocale.zhTw => 'Noto Sans CJK TC',
      _ => 'Noto Sans',
    };
  } else {
    fontFamily = 'Nunito';
  }

  const pill = StadiumBorder();
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);
  const buttonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    // same density on all platforms so desktop matches mobile (defaults to compact on desktop)
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: _duckTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      indicatorColor: colorScheme.primaryContainer,
      indicatorShape: pill,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      indicatorShape: pill,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      border: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: colorScheme.primary, width: 1.5)),
      enabledBorder: inputBorder,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: pill, padding: buttonPadding, textStyle: buttonText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: pill,
        padding: buttonPadding,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        padding: buttonPadding,
        textStyle: buttonText,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: pill, padding: buttonPadding, textStyle: buttonText),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sheetRadius)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: _borderRadius),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: _borderRadius),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
    ),
    fontFamily: fontFamily,
  );
}

/// Figma text styles Duck/*: Display, Headline, Title, Subtitle, Body, Body strong, Label, Caption.
const _duckTextTheme = TextTheme(
  displaySmall: TextStyle(fontSize: 40, height: 48 / 40, fontWeight: FontWeight.w700),
  headlineMedium: TextStyle(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700),
  headlineSmall: TextStyle(fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w700),
  titleLarge: TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700),
  titleMedium: TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600),
  titleSmall: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
  bodyLarge: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400),
  bodyMedium: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400),
  bodySmall: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500),
  labelLarge: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
  labelMedium: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600),
  labelSmall: TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w600),
);

Future<void> updateSystemOverlayStyle(BuildContext context) async {
  final brightness = Theme.of(context).brightness;
  await updateSystemOverlayStyleWithBrightness(brightness);
}

Future<void> updateSystemOverlayStyleWithBrightness(Brightness brightness) async {
  if (checkPlatform([TargetPlatform.android])) {
    // See https://github.com/flutter/flutter/issues/90098
    final darkMode = brightness == Brightness.dark;
    final androidSdkInt = RefenaScope.defaultRef.read(deviceInfoProvider).androidSdkInt ?? 0;
    final bool edgeToEdge = androidSdkInt >= 29;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // ignore: unawaited_futures

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: edgeToEdge ? Colors.transparent : (darkMode ? Colors.black : Colors.white),
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: darkMode ? Brightness.light : Brightness.dark,
      ),
    );
  } else {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: brightness, // iOS
        statusBarColor: Colors.transparent, // Not relevant to this issue
      ),
    );
  }
}

extension ThemeDataExt on ThemeData {
  /// This is the actual [cardColor] being used.
  Color get cardColorWithElevation {
    return ElevationOverlay.applySurfaceTint(cardColor, colorScheme.surfaceTint, 1);
  }
}

extension ColorSchemeExt on ColorScheme {
  Color get warning {
    return Colors.orange;
  }

  Color? get secondaryContainerIfDark {
    return brightness == Brightness.dark ? secondaryContainer : null;
  }

  Color? get onSecondaryContainerIfDark {
    return brightness == Brightness.dark ? onSecondaryContainer : null;
  }
}

extension InputDecorationThemeExt on InputDecorationThemeData {
  BorderRadius get borderRadius => _borderRadius;
}

ColorScheme _determineColorScheme(ColorMode mode, Color customColor, Brightness brightness, DynamicColors? dynamicColors) {
  final defaultColorScheme = _duckScheme(brightness);

  final colorScheme = switch (mode) {
    ColorMode.system => brightness == Brightness.light ? dynamicColors?.light : dynamicColors?.dark,
    ColorMode.localsend => null,
    ColorMode.oled => _duckScheme(Brightness.dark, oled: true),
    ColorMode.yaru => throw 'Should reach here',
    ColorMode.custom => ColorScheme.fromSeed(
      seedColor: customColor,
      brightness: brightness,
    ),
  };

  return colorScheme ?? defaultColorScheme;
}

ThemeData _getYaruTheme(Brightness brightness) {
  final baseTheme = brightness == Brightness.light ? yaru.yaruLight : yaru.yaruDark;
  final colorScheme = baseTheme.colorScheme;

  final lightInputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: colorScheme.secondaryContainer),
    borderRadius: _borderRadius,
  );

  final darkInputBorder = OutlineInputBorder(
    borderSide: BorderSide(color: colorScheme.secondaryContainer),
    borderRadius: _borderRadius,
  );

  InputDecorationThemeData;

  return baseTheme.copyWith(
    // same density on all platforms so desktop matches mobile (defaults to compact on desktop)
    visualDensity: VisualDensity.standard,
    navigationBarTheme: colorScheme.brightness == Brightness.dark
        ? NavigationBarThemeData(
            iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.white)),
          )
        : null,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.secondaryContainer,
      border: colorScheme.brightness == Brightness.light ? lightInputBorder : darkInputBorder,
      focusedBorder: colorScheme.brightness == Brightness.light ? lightInputBorder : darkInputBorder,
      enabledBorder: colorScheme.brightness == Brightness.light ? lightInputBorder : darkInputBorder,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: colorScheme.brightness == Brightness.dark ? Colors.white : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
  );
}
