import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Staggered list entrance (Design 2.0): fade + slide up, each item a bit
/// later than the previous one. Delays live inside the effects (no extra
/// timers), capped so long lists don't keep the user waiting. Respects the
/// system «reduce motion» setting.
extension PharmacyStaggerIn on Widget {
  Widget staggerIn(int index) => _StaggerIn(index: index, child: this);
}

class _StaggerIn extends StatelessWidget {
  const _StaggerIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final delay = Duration(milliseconds: 45 * index.clamp(0, 8));
    return child
        .animate()
        .fadeIn(delay: delay, duration: 320.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.12,
          end: 0,
          delay: delay,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
