import 'package:flutter/material.dart';

/// Whether the platform asked for reduced motion.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Gives a child a subtle press-down scale. It never handles the tap itself,
/// so the wrapped button or InkWell keeps its own behaviour and semantics.
class Pressable extends StatefulWidget {
  const Pressable({required this.child, this.enabled = true, super.key});

  final Widget child;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || reduceMotionOf(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades and lifts its child into place once, when first built.
/// Used sparingly on screen sections; skipped when reduced motion is on.
class EntranceFade extends StatelessWidget {
  const EntranceFade({required this.child, this.delayIndex = 0, super.key});

  final Widget child;

  /// Staggers sections slightly: each step adds 40 ms to the curve start.
  final int delayIndex;

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return child;
    final duration = Duration(milliseconds: 320 + 40 * delayIndex.clamp(0, 6));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
