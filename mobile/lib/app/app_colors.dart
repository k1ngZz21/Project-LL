import 'package:flutter/material.dart';

/// LearnLite's palette: Subanen red, gold, black and cream.
///
/// The first block is the established brand palette. The second block holds
/// tones derived from it (lighter or deeper versions of the same hues) that
/// the design system uses for surfaces, text and feedback. No new hues are
/// introduced.
abstract final class AppColors {
  // Established brand palette.
  static const primary = Color(0xFFC8202A);
  static const redDark = Color(0xFFA3171F);
  static const darkBackground = Color(0xFF111111);
  static const cream = Color(0xFFFAF3E8);
  static const creamSecondary = Color(0xFFF3E9D8);
  static const gold = Color(0xFFF5C518);
  static const white = Color(0xFFFFFFFF);
  static const lightPink = Color(0xFFFDE8E8);
  static const gray = Color(0xFF7A7368);
  static const border = Color(0xFFEADFCC);

  // Derived tones.
  /// Warm near-black for body text; softer on cream than pure black.
  static const ink = Color(0xFF1C1815);

  /// Secondary text with stronger contrast than [gray].
  static const inkSoft = Color(0xFF5C544B);

  /// Deep gold for gold text on light surfaces (readable contrast).
  static const goldDeep = Color(0xFF9A6B00);

  /// Pale gold wash for highlights and XP chips.
  static const goldSoft = Color(0xFFFFF3C4);

  /// Hairline border for elevated white cards.
  static const borderSoft = Color(0xFFF0E7D8);

  /// Charcoal used for dark feature cards, a step above [darkBackground].
  static const charcoal = Color(0xFF1E1A17);

  /// Answer feedback (already used by the quiz before this redesign).
  static const success = Color(0xFF287A45);
  static const successSoft = Color(0xFFDDF3E4);

  /// Warm shadow tint so elevation reads as depth, not grey dirt.
  static const shadow = Color(0xFF5A3A1A);
}
