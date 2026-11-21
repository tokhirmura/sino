import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_tokens.dart';

/// Slight scale-down while pressed and a springy release.
///
/// Purely visual: it only listens to pointers, so taps still go to the
/// child's own `InkWell` / button. [enabled] = false renders [child] as is.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
  });

  final Widget child;
  final bool enabled;

  /// Scale while the pointer is down.
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? AppMotion.fast : AppMotion.slow,
        curve: _down ? Curves.easeOut : AppMotion.spring,
        child: widget.child,
      ),
    );
  }
}

/// Fade + slide-up entrance. Widgets mounted in the same frame appear one
/// after another (cascade), so a freshly opened list "flows" in top-down.
///
/// Built into [AppCard]; wrap anything else with `CascadeIn(child: …)`.
/// Respects the system «reduce motion» setting. Driven by its own ticker
/// (no timers), so widget tests need no extra pumps.
class CascadeIn extends StatefulWidget {
  const CascadeIn({super.key, required this.child, this.index});

  final Widget child;

  /// Fixed position in the cascade; by default the order of mounting
  /// within the current frame.
  final int? index;

  @override
  State<CascadeIn> createState() => _CascadeInState();
}

class _CascadeInState extends State<CascadeIn>
    with SingleTickerProviderStateMixin {
  static int _inFrame = 0;
  static bool _resetScheduled = false;
  static const _maxIndex = 8;

  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final index = (widget.index ?? _inFrame++).clamp(0, _maxIndex);
    if (!_resetScheduled) {
      _resetScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _inFrame = 0;
        _resetScheduled = false;
      });
    }
    final delay = AppMotion.stagger * index;
    final total = delay + AppMotion.medium;
    _c = AnimationController(vsync: this, duration: total);
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppMotion.enter,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else if (_c.isDismissed) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      // Same widget structure in every frame, so the child keeps its state
      // (Opacity 1 paints without an extra layer).
      builder: (context, child) => Opacity(
        opacity: _t.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}
