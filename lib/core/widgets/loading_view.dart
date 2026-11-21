import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Unified loading state.
///
/// Design 2.0: instead of a spinner, a shimmering skeleton of cards that
/// fits the available height. [compact] — three pulsing brand dots for a
/// section inside a scrolling page.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return const _Dots();
    return LayoutBuilder(
      builder: (context, c) {
        final msg = message == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              );
        if (!c.hasBoundedHeight) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [?msg, const SkeletonLoader(count: 2)],
          );
        }
        if (c.maxHeight < 120) return const Center(child: _Dots());
        const row = 84.0 + AppSpacing.cardGap;
        final count = math.max(1, math.min(5, (c.maxHeight - 24) ~/ row));
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?msg,
                  SkeletonLoader(count: count),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [AppColors.primary, Color(0xFF168BC9), AppColors.secondary];
    return Semantics(
      label: 'loading',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Transform.scale(
                  // Each dot pulses a third of a cycle after the previous.
                  scale:
                      0.6 +
                      0.5 *
                          (0.5 +
                              0.5 * math.sin((_c.value - i / 3) * 2 * math.pi)),
                  child: Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmering placeholder block for skeleton loading.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1B263B) : const Color(0xFFEFEAE2);
    final shine = isDark ? const Color(0xFF29364F) : const Color(0xFFFBF9F5);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // A soft light band sweeps from left to right.
        final x = -1.6 + 3.2 * _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 0.6, -0.3),
              end: Alignment(x + 0.6, 0.3),
              colors: [base, shine, base],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton of a list of [ShortcutCard]-like rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3, this.itemHeight = 76});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == count - 1 ? 0 : AppSpacing.cardGap,
            ),
            child: Skeleton(height: itemHeight, radius: AppColors.cardRadius),
          ),
      ],
    );
  }
}

enum SkeletonKind {
  /// Card rows: icon square + two text lines (lists of items).
  list,

  /// Big content cards: title line + block.
  card,

  /// Two-column tiles (stats, services).
  grid,
}

/// Skeleton screen placeholder that looks like the content to come —
/// use instead of a spinner:
///
/// ```dart
/// AsyncValueView(
///   value: ref.watch(doctorsProvider),
///   loading: () => const SkeletonLoader(count: 4),
///   data: …,
/// )
/// ```
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.count = 3,
    this.kind = SkeletonKind.list,
  });

  final int count;
  final SkeletonKind kind;

  @override
  Widget build(BuildContext context) {
    final items = switch (kind) {
      SkeletonKind.list => [for (var i = 0; i < count; i++) _row(context, i)],
      SkeletonKind.card => [for (var i = 0; i < count; i++) _card(context)],
      SkeletonKind.grid => [
        for (var i = 0; i < (count + 1) ~/ 2; i++)
          Row(
            children: [
              Expanded(child: _tile(context)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: i * 2 + 1 < count ? _tile(context) : const SizedBox(),
              ),
            ],
          ),
      ],
    };
    return Semantics(
      label: 'loading',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == items.length - 1 ? 0 : AppSpacing.cardGap,
              ),
              child: items[i],
            ),
        ],
      ),
    );
  }

  Widget _shell(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        border: theme.brightness == Brightness.dark
            ? Border.all(color: theme.colorScheme.outlineVariant)
            : null,
      ),
      child: child,
    );
  }

  Widget _row(BuildContext context, int i) => _shell(
    context,
    Row(
      children: [
        const Skeleton(width: 52, height: 52, radius: 16),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: i.isEven ? 0.7 : 0.55,
                child: const Skeleton(height: 14),
              ),
              const SizedBox(height: 10),
              const FractionallySizedBox(
                widthFactor: 0.4,
                child: Skeleton(height: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _card(BuildContext context) => _shell(
    context,
    const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FractionallySizedBox(widthFactor: 0.5, child: Skeleton(height: 16)),
        SizedBox(height: 14),
        Skeleton(height: 96, radius: 16),
      ],
    ),
  );

  Widget _tile(BuildContext context) => _shell(
    context,
    const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(width: 36, height: 36, radius: 12),
        SizedBox(height: 14),
        FractionallySizedBox(widthFactor: 0.6, child: Skeleton(height: 22)),
        SizedBox(height: 8),
        FractionallySizedBox(widthFactor: 0.8, child: Skeleton(height: 11)),
      ],
    ),
  );
}
