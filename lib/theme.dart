import 'package:flutter/material.dart';

/// Design tokens for the "Shelf" direction.
///
/// Ground is petrol ink in the dark theme and mint-grey paper in the light
/// one; both are chromatic on purpose. Structure is carried by hairline
/// rules, never by elevation or shadow.
///
/// The accent (brass) has exactly one meaning: where you are in a title.
/// It is allowed on the current-chapter numeral and nowhere else -- not on
/// navigation, headings, buttons, or the cover art.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // Ground and surfaces.
  final Color ground;
  final Color groundSunken;
  final Color surface;
  final Color surfaceAlt;
  final Color rule;
  final Color ruleStrong;

  // Ink.
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color inkGhost;

  // Meaningful colour.
  final Color accent; // reading position, only
  final Color accentQuiet; // accent at low emphasis, e.g. text selection
  final Color onAccent;
  final Color done;
  final Color danger;

  /// The chapter stepper: a control panel lifted off the row. In both
  /// themes it reads as raised, because the app's primary action must never
  /// be the least visible thing on the row.
  final Color raised;

  const AppTokens({
    required this.ground,
    required this.groundSunken,
    required this.surface,
    required this.surfaceAlt,
    required this.rule,
    required this.ruleStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.inkGhost,
    required this.accent,
    required this.accentQuiet,
    required this.onAccent,
    required this.done,
    required this.danger,
    required this.raised,
  });

  static const dark = AppTokens(
    ground: Color(0xFF16232A),
    groundSunken: Color(0xFF101A20),
    surface: Color(0xFF1F303A),
    surfaceAlt: Color(0xFF23353E),
    rule: Color(0xFF2C4149),
    ruleStrong: Color(0xFF3A545E),
    ink: Color(0xFFE7E4DC),
    inkMuted: Color(0xFFA9B4B6),
    inkFaint: Color(0xFF8A9A9E),
    inkGhost: Color(0xFF5B6E73),
    accent: Color(0xFFE0A93C),
    accentQuiet: Color(0xFF8A6A25),
    onAccent: Color(0xFF16232A),
    done: Color(0xFF6FAE95),
    danger: Color(0xFFD4736A),
    raised: Color(0xFF2A414C),
  );

  static const light = AppTokens(
    ground: Color(0xFFE5EAE8),
    groundSunken: Color(0xFFD7DEDC),
    surface: Color(0xFFF2F5F3),
    surfaceAlt: Color(0xFFDDE5E2),
    rule: Color(0xFFC3CFCB),
    ruleStrong: Color(0xFFA6B5B0),
    ink: Color(0xFF14242B),
    inkMuted: Color(0xFF445A61),
    inkFaint: Color(0xFF56696F),
    inkGhost: Color(0xFF7E9095),
    accent: Color(0xFF7F5709),
    accentQuiet: Color(0xFFB98F33),
    onAccent: Color(0xFFFDFBF6),
    done: Color(0xFF276754),
    danger: Color(0xFFA33A31),
    raised: Color(0xFFFAFCFB),
  );

  /// Spine dyes for titles with no cover art. Hand-picked, not generated:
  /// six traditional dye colours that read as book spines against either
  /// ground.
  static const spineDyes = <Color>[
    Color(0xFF3E5C6B), // ai-nezumi, blue grey
    Color(0xFF6B4A3E), // kogecha, burnt brown
    Color(0xFF4A5B3C), // moegi, moss
    Color(0xFF6B4356), // budo, grape
    Color(0xFF7A5C2E), // kuchiba, ochre
    Color(0xFF33565C), // asagi, teal
  ];

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) =>
      t < 0.5 ? this : (other as AppTokens? ?? this);
}

extension TokensOf on BuildContext {
  AppTokens get tk => Theme.of(this).extension<AppTokens>()!;
}

/// Radius scale. Structure is square; only controls are softened.
abstract class R {
  static const badge = Radius.circular(3);
  static const control = Radius.circular(6);
  static const sheet = Radius.circular(12);
}

/// Motion. Two things animate in this app: the chapter numeral when it
/// changes, and a cover fading in once it loads.
abstract class Motion {
  static const micro = Duration(milliseconds: 140);
  static const state = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;

  /// Honours the platform "remove animations" accessibility setting.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;
}

abstract class Faces {
  static const display = 'PlexSerif';
  static const body = 'PlexSans';
  static const utility = 'PlexMono';
}

/// Type scale. Face is tied to role: serif names things, sans explains
/// things, mono counts things.
abstract class Type {
  static const _tabular = [FontFeature.tabularFigures()];

  /// Sheet titles and the wordmark.
  static const display = TextStyle(
    fontFamily: Faces.display,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.2,
  );

  /// A manga title, on a shelf row.
  static const title = TextStyle(
    fontFamily: Faces.display,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  static const body = TextStyle(
    fontFamily: Faces.body,
    fontSize: 14,
    height: 1.4,
  );

  static const bodySm = TextStyle(
    fontFamily: Faces.body,
    fontSize: 13,
    height: 1.4,
  );

  /// Button and control text.
  static const label = TextStyle(
    fontFamily: Faces.body,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// The chapter you are on. The one place the accent is allowed.
  static const number = TextStyle(
    fontFamily: Faces.utility,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );

  static const numberSm = TextStyle(
    fontFamily: Faces.utility,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.0,
    fontFeatures: _tabular,
  );

  /// Timestamps, counts, anything measured.
  static const meta = TextStyle(
    fontFamily: Faces.utility,
    fontSize: 11.5,
    height: 1.2,
    letterSpacing: 0.2,
    fontFeatures: _tabular,
  );

  /// Section and band headings.
  static const eyebrow = TextStyle(
    fontFamily: Faces.utility,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 1.2,
    fontFeatures: _tabular,
  );
}

ThemeData buildTheme(Brightness brightness) {
  final t = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: Faces.body,
    scaffoldBackgroundColor: t.ground,
    canvasColor: t.ground,
    dividerColor: t.rule,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: t.ink,
      onPrimary: t.ground,
      secondary: t.accent,
      onSecondary: t.onAccent,
      surface: t.surface,
      onSurface: t.ink,
      error: t.danger,
      onError: t.onAccent,
    ),
  );

  return base.copyWith(
    extensions: [t],
    appBarTheme: AppBarTheme(
      backgroundColor: t.ground,
      foregroundColor: t.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(color: t.rule, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: t.inkMuted, size: 20),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.surface,
      contentTextStyle: Type.bodySm.copyWith(color: t.ink),
      actionTextColor: t.ink,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(R.control),
        side: BorderSide(color: t.ruleStrong),
      ),
    ),
    // Ledger fields: a ruled line to write on, not a filled pill.
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isDense: true,
      hintStyle: Type.body.copyWith(color: t.inkGhost),
      contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 9),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.ruleStrong),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.ink, width: 1.5),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.danger),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.danger, width: 1.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: R.sheet),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: Type.display.copyWith(fontSize: 17, color: t.ink),
      contentTextStyle: Type.bodySm.copyWith(color: t.inkMuted),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(R.control),
        side: BorderSide(color: t.ruleStrong),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      textStyle: Type.bodySm.copyWith(color: t.ink),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(R.control),
        side: BorderSide(color: t.ruleStrong),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.inkMuted,
        textStyle: Type.label,
        minimumSize: const Size(64, 44),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(R.control),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.ink,
        foregroundColor: t.ground,
        textStyle: Type.label,
        elevation: 0,
        minimumSize: const Size(64, 48),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(R.control),
        ),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.ink,
      selectionColor: t.accentQuiet.withValues(alpha: 0.35),
      selectionHandleColor: t.ink,
    ),
  );
}
