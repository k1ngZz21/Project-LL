import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/core/avatar_design.dart';
import 'package:learnlite/widgets/learner_avatar.dart';
import 'package:learnlite/widgets/subanen_avatar.dart';

void main() {
  test('a design survives encoding and decoding', () {
    const design = AvatarDesign(
      gender: AvatarGender.male,
      skinTone: 4,
      hairStyle: 1,
      hairColor: 2,
      outfitColor: 3,
      pattern: AvatarPattern.diamond,
      background: 4,
      beads: false,
      earrings: true,
      headCloth: true,
    );
    final stored = design.encode();
    expect(stored, startsWith('sbn1:'));
    expect(AvatarDesign.tryParse(stored), design);
  });

  test('non-avatar values are ignored and bad numbers are clamped', () {
    for (final value in [null, '', 'https://example.org/a.png', 'sbn9:g=f']) {
      expect(AvatarDesign.tryParse(value), isNull, reason: '$value');
    }
    final clamped = AvatarDesign.tryParse('sbn1:g=x;s=99;h=-4;p=7;bg=abc')!;
    expect(clamped.gender, AvatarGender.female);
    expect(clamped.skinTone, AvatarDesign.skinTones.length - 1);
    expect(clamped.hairStyle, 0);
    expect(clamped.pattern, AvatarPattern.plain);
    expect(clamped.background, 0);
  });

  test('outfit colour is stored as hex and described for screen readers', () {
    const design = AvatarDesign(outfitColor: 0, earrings: true);
    expect(design.outfitHex, '#C8202A');
    expect(design.description, contains('Woman avatar'));
    expect(design.description, contains('earrings'));
  });

  testWidgets('every combination draws without errors', (tester) async {
    final designs = [
      for (final gender in AvatarGender.values)
        for (var hair = 0; hair < 3; hair++)
          for (final pattern in AvatarPattern.values)
            for (final cloth in [false, true])
              AvatarDesign(
                gender: gender,
                hairStyle: hair,
                pattern: pattern,
                headCloth: cloth,
                beads: hair.isEven,
                earrings: cloth,
                outfitColor: (hair + pattern.index) % 5,
                background: pattern.index,
              ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Wrap(
            children: [
              for (final d in designs) SubanenAvatar(design: d, size: 64),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SubanenAvatar), findsNWidgets(designs.length));
  });

  testWidgets('LearnerAvatar draws a stored design and falls back otherwise',
      (tester) async {
    final stored = const AvatarDesign(gender: AvatarGender.male).encode();
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            LearnerAvatar(avatarId: stored),
            const LearnerAvatar(),
          ],
        ),
      ),
    );
    expect(find.byType(SubanenAvatar), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Man avatar')), findsOneWidget);
    expect(find.bySemanticsLabel('No learner avatar set'), findsOneWidget);
  });
}
