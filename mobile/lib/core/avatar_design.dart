import 'dart:ui' show Color;

import '../app/app_colors.dart';

/// A learner's drawn avatar: no photos and no image files.
///
/// The look borrows LearnLite's woven red, gold and black geometric bands
/// (the same motif as the app's decorative border). It is an inspired
/// design, not a depiction of official or ceremonial Subanen attire.
///
/// Stored in the existing `learners.avatar_id` column as a short versioned
/// string, so no schema change is needed:
/// `sbn1:g=f;s=2;h=0;c=0;o=0;p=1;bg=0;b=1;e=1;w=0`.
enum AvatarGender { female, male }

enum AvatarPattern { zigzag, diamond, stripes, plain }

class AvatarDesign {
  const AvatarDesign({
    this.gender = AvatarGender.female,
    this.skinTone = 2,
    this.hairStyle = 0,
    this.hairColor = 0,
    this.outfitColor = 0,
    this.pattern = AvatarPattern.zigzag,
    this.background = 0,
    this.beads = true,
    this.earrings = false,
    this.headCloth = false,
  });

  static const prefix = 'sbn1:';

  final AvatarGender gender;
  final int skinTone;
  final int hairStyle;
  final int hairColor;
  final int outfitColor;
  final AvatarPattern pattern;
  final int background;
  final bool beads;
  final bool earrings;
  final bool headCloth;

  static const skinTones = [
    Color(0xFFF1C9A5),
    Color(0xFFDDA67C),
    Color(0xFFC08A5B),
    Color(0xFF9C6A43),
    Color(0xFF6E4A2F),
  ];
  static const skinToneNames = ['Light', 'Light brown', 'Brown', 'Tan', 'Deep'];

  static const hairColors = [
    Color(0xFF15110E),
    Color(0xFF3B2618),
    Color(0xFF6B4A2E),
    Color(0xFF8E8A86),
  ];
  static const hairColorNames = ['Black', 'Dark brown', 'Brown', 'Gray'];

  static const femaleHairStyles = ['Long', 'Bun', 'Braid'];
  static const maleHairStyles = ['Short', 'Wavy', 'Top knot'];

  static const outfitColors = [
    AppColors.primary,
    AppColors.darkBackground,
    AppColors.redDark,
    AppColors.goldDeep,
    AppColors.cream,
  ];
  static const outfitColorNames = ['Red', 'Black', 'Deep red', 'Gold', 'Cream'];

  static const patternNames = {
    AvatarPattern.zigzag: 'Zigzag',
    AvatarPattern.diamond: 'Diamond',
    AvatarPattern.stripes: 'Stripes',
    AvatarPattern.plain: 'Plain',
  };

  static const backgrounds = [
    AppColors.lightPink,
    AppColors.goldSoft,
    AppColors.creamSecondary,
    AppColors.primary,
    AppColors.charcoal,
  ];
  static const backgroundNames = ['Pink', 'Gold', 'Cream', 'Red', 'Charcoal'];

  List<String> get hairStyleNames =>
      gender == AvatarGender.female ? femaleHairStyles : maleHairStyles;

  Color get skin => skinTones[skinTone];
  Color get hair => hairColors[hairColor];
  Color get outfit => outfitColors[outfitColor];
  Color get backgroundColor => backgrounds[background];

  /// Hex form of the outfit colour, kept in `learners.outfit_color`.
  String get outfitHex =>
      '#${outfit.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  String encode() => '$prefix'
      'g=${gender == AvatarGender.female ? 'f' : 'm'};'
      's=$skinTone;h=$hairStyle;c=$hairColor;o=$outfitColor;'
      'p=${pattern.index};bg=$background;'
      'b=${beads ? 1 : 0};e=${earrings ? 1 : 0};w=${headCloth ? 1 : 0}';

  /// Reads a stored design. Returns null for anything that is not a LearnLite
  /// avatar (empty, a URL from older data, or an unknown version), so callers
  /// fall back to the generic icon. Out-of-range values are clamped.
  static AvatarDesign? tryParse(String? value) {
    if (value == null || !value.startsWith(prefix)) return null;
    final fields = <String, String>{};
    for (final part in value.substring(prefix.length).split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      fields[part.substring(0, separator)] = part.substring(separator + 1);
    }
    int number(String key, int max) =>
        (int.tryParse(fields[key] ?? '') ?? 0).clamp(0, max);
    return AvatarDesign(
      gender: fields['g'] == 'm' ? AvatarGender.male : AvatarGender.female,
      skinTone: number('s', skinTones.length - 1),
      hairStyle: number('h', 2),
      hairColor: number('c', hairColors.length - 1),
      outfitColor: number('o', outfitColors.length - 1),
      pattern: AvatarPattern.values[number('p', AvatarPattern.values.length - 1)],
      background: number('bg', backgrounds.length - 1),
      beads: fields['b'] == '1',
      earrings: fields['e'] == '1',
      headCloth: fields['w'] == '1',
    );
  }

  AvatarDesign copyWith({
    AvatarGender? gender,
    int? skinTone,
    int? hairStyle,
    int? hairColor,
    int? outfitColor,
    AvatarPattern? pattern,
    int? background,
    bool? beads,
    bool? earrings,
    bool? headCloth,
  }) => AvatarDesign(
    gender: gender ?? this.gender,
    skinTone: skinTone ?? this.skinTone,
    hairStyle: hairStyle ?? this.hairStyle,
    hairColor: hairColor ?? this.hairColor,
    outfitColor: outfitColor ?? this.outfitColor,
    pattern: pattern ?? this.pattern,
    background: background ?? this.background,
    beads: beads ?? this.beads,
    earrings: earrings ?? this.earrings,
    headCloth: headCloth ?? this.headCloth,
  );

  /// Short description for screen readers.
  String get description {
    final person = gender == AvatarGender.female ? 'Woman' : 'Man';
    final extras = [
      if (beads) 'bead necklace',
      if (earrings) 'earrings',
      if (headCloth) 'head cloth',
    ];
    return '$person avatar, ${skinToneNames[skinTone].toLowerCase()} skin, '
        '${hairColorNames[hairColor].toLowerCase()} '
        '${hairStyleNames[hairStyle].toLowerCase()} hair, '
        '${outfitColorNames[outfitColor].toLowerCase()} top with '
        '${patternNames[pattern]!.toLowerCase()} band'
        '${extras.isEmpty ? '' : ', ${extras.join(', ')}'}';
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarDesign && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
