import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../core/avatar_design.dart';
import '../../widgets/subanen_avatar.dart';

/// Controls for building an [AvatarDesign]. The caller shows the preview and
/// saves; this widget only reports changes.
class AvatarBuilder extends StatelessWidget {
  const AvatarBuilder({
    required this.design,
    required this.onChanged,
    this.random,
    super.key,
  });

  final AvatarDesign design;
  final ValueChanged<AvatarDesign> onChanged;
  final math.Random? random;

  void _surprise() {
    final rng = random ?? math.Random();
    final gender = AvatarGender.values[rng.nextInt(2)];
    onChanged(
      AvatarDesign(
        gender: gender,
        skinTone: rng.nextInt(AvatarDesign.skinTones.length),
        hairStyle: rng.nextInt(3),
        hairColor: rng.nextInt(AvatarDesign.hairColors.length - 1),
        outfitColor: rng.nextInt(AvatarDesign.outfitColors.length),
        pattern: AvatarPattern.values[rng.nextInt(3)],
        background: rng.nextInt(AvatarDesign.backgrounds.length),
        beads: rng.nextBool(),
        earrings: rng.nextBool(),
        headCloth: rng.nextInt(4) == 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Character', style: textTheme.titleSmall),
            ),
            TextButton.icon(
              key: const ValueKey('avatar-surprise'),
              onPressed: _surprise,
              icon: const Icon(Icons.casino_outlined, size: 18),
              label: const Text('Surprise me'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final gender in AvatarGender.values) ...[
              Expanded(
                child: _CharacterChoice(
                  key: ValueKey('avatar-gender-${gender.name}'),
                  label: gender == AvatarGender.female ? 'Female' : 'Male',
                  selected: design.gender == gender,
                  preview: design.copyWith(
                    gender: gender,
                    hairStyle: 0,
                    earrings: gender == AvatarGender.female
                        ? design.earrings
                        : false,
                  ),
                  onTap: () => onChanged(
                    design.copyWith(gender: gender, hairStyle: 0),
                  ),
                ),
              ),
              if (gender == AvatarGender.female) const SizedBox(width: 12),
            ],
          ],
        ),
        _Section(
          title: 'Skin tone',
          child: _SwatchRow(
            keyPrefix: 'avatar-skin',
            colors: AvatarDesign.skinTones,
            names: AvatarDesign.skinToneNames,
            selected: design.skinTone,
            onSelected: (i) => onChanged(design.copyWith(skinTone: i)),
          ),
        ),
        _Section(
          title: 'Hair',
          child: _ChipRow(
            keyPrefix: 'avatar-hair',
            labels: design.hairStyleNames,
            selected: design.hairStyle,
            onSelected: (i) => onChanged(design.copyWith(hairStyle: i)),
          ),
        ),
        _Section(
          title: 'Hair colour',
          child: _SwatchRow(
            keyPrefix: 'avatar-hair-color',
            colors: AvatarDesign.hairColors,
            names: AvatarDesign.hairColorNames,
            selected: design.hairColor,
            onSelected: (i) => onChanged(design.copyWith(hairColor: i)),
          ),
        ),
        _Section(
          title: 'Outfit colour',
          child: _SwatchRow(
            keyPrefix: 'avatar-outfit',
            colors: AvatarDesign.outfitColors,
            names: AvatarDesign.outfitColorNames,
            selected: design.outfitColor,
            onSelected: (i) => onChanged(design.copyWith(outfitColor: i)),
          ),
        ),
        _Section(
          title: 'Woven band',
          child: _ChipRow(
            keyPrefix: 'avatar-pattern',
            labels: [
              for (final p in AvatarPattern.values)
                AvatarDesign.patternNames[p]!,
            ],
            selected: design.pattern.index,
            onSelected: (i) =>
                onChanged(design.copyWith(pattern: AvatarPattern.values[i])),
          ),
        ),
        _Section(
          title: 'Accessories',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Toggle(
                key: const ValueKey('avatar-beads'),
                label: 'Bead necklace',
                value: design.beads,
                onChanged: (v) => onChanged(design.copyWith(beads: v)),
              ),
              _Toggle(
                key: const ValueKey('avatar-earrings'),
                label: 'Earrings',
                value: design.earrings,
                onChanged: (v) => onChanged(design.copyWith(earrings: v)),
              ),
              _Toggle(
                key: const ValueKey('avatar-head-cloth'),
                label: 'Head cloth',
                value: design.headCloth,
                onChanged: (v) => onChanged(design.copyWith(headCloth: v)),
              ),
            ],
          ),
        ),
        _Section(
          title: 'Background',
          child: _SwatchRow(
            keyPrefix: 'avatar-background',
            colors: AvatarDesign.backgrounds,
            names: AvatarDesign.backgroundNames,
            selected: design.background,
            onSelected: (i) => onChanged(design.copyWith(background: i)),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Drawn in LearnLite\'s woven red, gold and black style. It is an '
          'inspired design, not official or ceremonial Subanen attire. No '
          'photos are used or uploaded.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.gray),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _CharacterChoice extends StatelessWidget {
  const _CharacterChoice({
    required this.label,
    required this.selected,
    required this.preview,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final AvatarDesign preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label character',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightPink : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            ClipOval(child: SubanenAvatar(design: preview, size: 72)),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({
    required this.keyPrefix,
    required this.colors,
    required this.names,
    required this.selected,
    required this.onSelected,
  });

  final String keyPrefix;
  final List<Color> colors;
  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (var i = 0; i < colors.length; i++)
        Semantics(
          button: true,
          selected: i == selected,
          label: names[i],
          excludeSemantics: true,
          child: Tooltip(
            message: names[i],
            child: InkResponse(
              key: ValueKey('$keyPrefix-$i'),
              onTap: () => onSelected(i),
              radius: 26,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == selected ? AppColors.primary : AppColors.border,
                    width: i == selected ? 3 : 1.5,
                  ),
                ),
                child: i == selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: colors[i].computeLuminance() > 0.5
                            ? AppColors.ink
                            : AppColors.white,
                      )
                    : null,
              ),
            ),
          ),
        ),
    ],
  );
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.keyPrefix,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final String keyPrefix;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < labels.length; i++)
        ChoiceChip(
          key: ValueKey('$keyPrefix-$i'),
          label: Text(labels[i]),
          selected: i == selected,
          onSelected: (_) => onSelected(i),
          selectedColor: AppColors.lightPink,
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: i == selected ? AppColors.primary : AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
          side: BorderSide(
            color: i == selected ? AppColors.primary : AppColors.border,
          ),
        ),
    ],
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: value,
    onSelected: onChanged,
    selectedColor: AppColors.goldSoft,
    checkmarkColor: AppColors.goldDeep,
    labelStyle: TextStyle(
      color: value ? AppColors.goldDeep : AppColors.ink,
      fontWeight: FontWeight.w700,
    ),
    side: BorderSide(color: value ? AppColors.goldDeep : AppColors.border),
  );
}
