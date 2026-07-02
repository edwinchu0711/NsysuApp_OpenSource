import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: Color(0xFF2196F3),
    primaryContainer: Color(0xFFE3F2FD),
    onPrimaryContainer: Color(0xFF0D47A1),
    secondary: Color(0xFF03A9F4),
    surface: Colors.white,
    onSurface: Color(0xFF1A1A1A),
    onPrimary: Colors.white,
  );

  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: Color(0xFF6B9BF5),
    primaryContainer: Color(0xFF1E2D4A),
    onPrimaryContainer: Color(0xFFD1E4FF),
    secondary: Color(0xFF4FC3F7),
    surface: Color(0xFF1E2432),
    onSurface: Color(0xFFE8EAF0),
    onPrimary: Colors.white,
  );

  static ThemeData get lightTheme => buildTheme(lightColorScheme, 'system');
  static ThemeData get darkTheme => buildTheme(darkColorScheme, 'system');

  static ThemeData buildTheme(
    ColorScheme colorScheme,
    String fontFamilySetting,
  ) {
    final String activeFont = fontFamilySetting == 'NotoSansTC'
        ? (GoogleFonts.notoSansTc().fontFamily ?? 'NotoSansTC')
        : 'MyVariableFont';

    final isDark = colorScheme.brightness == Brightness.dark;
    const double defaultLetterSpacing = 0.75;

    final baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final basePrimaryTextTheme = isDark
        ? ThemeData.dark().primaryTextTheme
        : ThemeData.light().primaryTextTheme;

    final customTextTheme = TextTheme(
      bodyLarge: TextStyle(
        fontFamily: activeFont,
        fontFamilyFallback: const <String>[
          'Roboto',
          'Noto Sans CJK TC',
          'sans-serif',
        ],
        letterSpacing: defaultLetterSpacing,
        color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A1A),
      ),
      bodyMedium: TextStyle(
        fontFamily: activeFont,
        fontFamilyFallback: const <String>[
          'Roboto',
          'Noto Sans CJK TC',
          'sans-serif',
        ],
        letterSpacing: defaultLetterSpacing,
        color: isDark ? const Color(0xFFB0B8C8) : const Color(0xFF555555),
      ),
      bodySmall: TextStyle(
        fontFamily: activeFont,
        fontFamilyFallback: const <String>[
          'Roboto',
          'Noto Sans CJK TC',
          'sans-serif',
        ],
        letterSpacing: defaultLetterSpacing,
        color: isDark ? const Color(0xFF8890A8) : Colors.grey[600],
      ),
      titleLarge: TextStyle(
        fontFamily: activeFont,
        fontFamilyFallback: const <String>[
          'Roboto',
          'Noto Sans CJK TC',
          'sans-serif',
        ],
        letterSpacing: defaultLetterSpacing,
        color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        fontFamily: activeFont,
        fontFamilyFallback: const <String>[
          'Roboto',
          'Noto Sans CJK TC',
          'sans-serif',
        ],
        letterSpacing: defaultLetterSpacing,
        color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A1A),
      ),
    );

    final finalTextTheme = baseTextTheme
        .merge(customTextTheme)
        .apply(
          fontFamily: activeFont,
          fontFamilyFallback: <String>[
            'Roboto',
            'Noto Sans CJK TC',
            'sans-serif',
          ],
        );

    final finalPrimaryTextTheme = basePrimaryTextTheme.apply(
      fontFamily: activeFont,
      fontFamilyFallback: <String>['Roboto', 'Noto Sans CJK TC', 'sans-serif'],
    );

    return ThemeData(
      useMaterial3: false,
      fontFamily: activeFont,
      fontFamilyFallback: const <String>[
        'Roboto',
        'Noto Sans CJK TC',
        'sans-serif',
      ],
      colorScheme: colorScheme,
      primaryColor: colorScheme.primary,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF151A26)
          : const Color(0xFFFAFAFA),
      cardColor: colorScheme.surface,

      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,

      dividerColor: isDark ? Colors.white12 : Colors.black26,
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : Colors.black26,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E2432) : Colors.white,
        foregroundColor: isDark
            ? const Color(0xFFE8EAF0)
            : const Color(0xFF1A1A1A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF1E2432) : Colors.white,
        titleTextStyle: TextStyle(
          fontFamily: activeFont,
          fontFamilyFallback: const <String>[
            'Roboto',
            'Noto Sans CJK TC',
            'sans-serif',
          ],
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: defaultLetterSpacing,
          color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A1A),
        ),
        contentTextStyle: TextStyle(
          fontFamily: activeFont,
          fontFamilyFallback: const <String>[
            'Roboto',
            'Noto Sans CJK TC',
            'sans-serif',
          ],
          fontSize: 14,
          letterSpacing: defaultLetterSpacing,
          color: isDark ? const Color(0xFFB0B8C8) : const Color(0xFF555555),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(
          fontFamily: activeFont,
          fontFamilyFallback: const <String>[
            'Roboto',
            'Noto Sans CJK TC',
            'sans-serif',
          ],
          letterSpacing: defaultLetterSpacing,
          color: isDark ? Colors.white54 : Colors.grey[700],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF6B9BF5) : const Color(0xFF2196F3),
          ),
        ),
        fillColor: isDark ? const Color(0xFF252B3B) : Colors.grey[100],
        filled: false,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF2E3547)
            : const Color(0xFF323232),
        contentTextStyle: TextStyle(
          fontFamily: activeFont,
          fontFamilyFallback: const <String>[
            'Roboto',
            'Noto Sans CJK TC',
            'sans-serif',
          ],
          color: Colors.white,
          letterSpacing: defaultLetterSpacing,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.5);
          }
          return isDark ? Colors.white24 : null;
        }),
      ),

      iconTheme: IconThemeData(
        color: isDark ? const Color(0xFFB0B8C8) : Colors.grey[700],
      ),

      textTheme: finalTextTheme,
      primaryTextTheme: finalPrimaryTextTheme,

      textSelectionTheme: TextSelectionThemeData(
        selectionColor: isDark
            ? const Color(0xFF90CAF9).withValues(alpha: 0.45)
            : const Color(0xFF1565C0).withValues(alpha: 0.35),
        selectionHandleColor: colorScheme.primary,
      ),

      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: colorScheme.brightness,
        primaryColor: colorScheme.primary,
        textTheme: CupertinoTextThemeData(
          primaryColor: colorScheme.primary,
          textStyle: TextStyle(
            fontFamily: activeFont,
            fontFamilyFallback: const <String>[
              'Roboto',
              'Noto Sans CJK TC',
              'sans-serif',
            ],
          ),
          actionTextStyle: TextStyle(
            fontFamily: activeFont,
            fontFamilyFallback: const <String>[
              'Roboto',
              'Noto Sans CJK TC',
              'sans-serif',
            ],
          ),
          tabLabelTextStyle: TextStyle(
            fontFamily: activeFont,
            fontFamilyFallback: const <String>[
              'Roboto',
              'Noto Sans CJK TC',
              'sans-serif',
            ],
          ),
          navTitleTextStyle: TextStyle(
            fontFamily: activeFont,
            fontFamilyFallback: const <String>[
              'Roboto',
              'Noto Sans CJK TC',
              'sans-serif',
            ],
          ),
          navLargeTitleTextStyle: TextStyle(
            fontFamily: activeFont,
            fontFamilyFallback: const <String>[
              'Roboto',
              'Noto Sans CJK TC',
              'sans-serif',
            ],
          ),
          navActionTextStyle: TextStyle(
            fontFamily: activeFont,
            fontFamilyFallback: const <String>[
              'Roboto',
              'Noto Sans CJK TC',
              'sans-serif',
            ],
          ),
          pickerTextStyle: TextStyle(
            fontFamily: activeFont,
            fontFamilyFallback: const <String>[
              'Roboto',
              'Noto Sans CJK TC',
              'sans-serif',
            ],
          ),
          dateTimePickerTextStyle: TextStyle(
            fontFamily: activeFont,
            fontFamilyFallback: const <String>[
              'Roboto',
              'Noto Sans CJK TC',
              'sans-serif',
            ],
          ),
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

extension AppColors on ColorScheme {
  bool get isDark => brightness == Brightness.dark;

  Color get pageBackground =>
      isDark ? const Color(0xFF151A26) : const Color(0xFFFAFAFA);

  Color get cardBackground => isDark ? const Color(0xFF1E2432) : Colors.white;

  Color get secondaryCardBackground =>
      isDark ? const Color(0xFF252B3B) : const Color(0xFFF2F4F7);

  Color get primaryText => isDark ? const Color(0xFFE8EAF0) : Colors.black87;

  Color get subtitleText =>
      isDark ? const Color(0xFF8890A8) : Colors.grey.shade600;

  Color get bodyText => isDark ? const Color(0xFFB0B8C8) : Colors.grey.shade700;

  Color get borderColor => isDark ? Colors.white12 : Colors.grey.shade300;

  Color get headerBackground => isDark ? const Color(0xFF1E2432) : Colors.white;

  Color get scaffoldBackground =>
      isDark ? const Color(0xFF151A26) : const Color(0xFFF8F9FA);

  Color get subtleBackground =>
      isDark ? const Color(0xFF252B3B) : Colors.grey.shade100;

  Color get successContainer =>
      isDark ? const Color(0xFF1B3921) : const Color(0xFFE8F5E9);

  Color get warningContainer =>
      isDark ? const Color(0xFF3E2D1A) : const Color(0xFFFFF3E0);

  Color get iconColor =>
      isDark ? const Color(0xFFB0B8C8) : Colors.grey.shade600;

  Color get accentBlue =>
      isDark ? const Color(0xFF6B9BF5) : Colors.blue.shade700;
}
