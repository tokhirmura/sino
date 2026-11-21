import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models.dart';

/// How far an active reservation got on «Qabul qilindi → Tayyorlanmoqda →
/// Tayyor»: the number of completed steps (0…3), `null` when it has no
/// progress to show (cancelled, picked up).
///
/// - sending (optimistic `pending-…` id): 0 — «Qabul qilindi» in progress
/// - `pending`: 1 — accepted, «Tayyorlanmoqda» in progress
/// - `ready`: 3 — all done
int? reservationProgress(Reservation r) {
  if (!r.status.isActive) return null;
  if (r.id.startsWith('pending-')) return 0;
  return r.status == ReservationStatus.ready ? 3 : 1;
}

/// Three-step progress bar of a reservation. Done steps — green with a
/// check, the current one — saffron, the rest — outlined. Changes animate
/// (finite animations only, so `pumpAndSettle` works in tests).
/// [compact] — smaller, for the home card.
class ReservationSteps extends StatelessWidget {
  const ReservationSteps({
    super.key,
    required this.reservation,
    this.compact = false,
  });

  final Reservation reservation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final done = reservationProgress(reservation);
    if (done == null) return const SizedBox.shrink();
    final labels = [
      context.tr(uz: 'Qabul qilindi', ru: 'Принят', en: 'Accepted'),
      context.tr(uz: 'Tayyorlanmoqda', ru: 'Собирается', en: 'Preparing'),
      context.tr(uz: 'Tayyor', ru: 'Готов', en: 'Ready'),
    ];
    return Semantics(
      label: labels.take(done.clamp(1, 3)).last,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: _Step(
                index: i,
                label: labels[i],
                state: i < done
                    ? _StepState.done
                    : i == done
                    ? _StepState.current
                    : _StepState.todo,
                // The line into this step is lit once the previous one is done.
                lineIn: i > 0 ? (i <= done) : null,
                lineOut: i < 2 ? (i + 1 <= done) : null,
                compact: compact,
              ),
            ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, todo }

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.label,
    required this.state,
    required this.lineIn,
    required this.lineOut,
    required this.compact,
  });

  final int index;
  final String label;
  final _StepState state;

  /// `null` — no line on that side (first / last step).
  final bool? lineIn;
  final bool? lineOut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final idle = theme.colorScheme.outlineVariant;
    final good = AppColors.readable(AppColors.good, brightness);
    final current = AppColors.readable(AppColors.saffron, brightness);
    final dot = compact ? 22.0 : 28.0;
    final color = switch (state) {
      _StepState.done => good,
      _StepState.current => current,
      _StepState.todo => idle,
    };
    const duration = Duration(milliseconds: 450);

    Widget line(bool? lit) => Expanded(
      child: lit == null
          ? const SizedBox()
          : AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              height: 4,
              decoration: BoxDecoration(
                color: lit ? good : idle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
    );

    return Column(
      children: [
        SizedBox(
          height: dot,
          child: Row(
            children: [
              line(lineIn),
              AnimatedContainer(
                duration: duration,
                // No overshoot: an overshooting curve drives the shadow blur < 0.
                curve: Curves.easeOutCubic,
                width: dot,
                height: dot,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == _StepState.todo
                      ? theme.colorScheme.surface
                      : color,
                  border: Border.all(color: color, width: 2),
                  boxShadow: state == _StepState.current
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: switch (state) {
                  _StepState.done => Icon(
                    Icons.check_rounded,
                    size: dot * 0.62,
                    color: Colors.white,
                  ),
                  _StepState.current => Icon(
                    Icons.more_horiz_rounded,
                    size: dot * 0.62,
                    color: Colors.white,
                  ),
                  _StepState.todo => Text(
                    '${index + 1}',
                    textScaler: TextScaler.noScaling,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                },
              ),
              line(lineOut),
            ],
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelMedium)
                    ?.copyWith(
                      color: state == _StepState.todo
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                      fontWeight: state == _StepState.todo
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
          ),
        ),
      ],
    );
  }
}
