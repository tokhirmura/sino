import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../application/pharmacy_providers.dart';
import '../../data/models.dart';
import 'reservation_steps.dart';

/// The reservation to show progress for: a ready one first (go and pick it
/// up), else the most recent one being prepared.
Reservation? focusReservation(List<Reservation> active) {
  for (final r in active) {
    if (r.status == ReservationStatus.ready) return r;
  }
  return active.isEmpty ? null : active.last;
}

/// Active reservations at a glance: count, «ready» line, the focused
/// reservation's medicine and its 3-step progress bar. Renders nothing
/// when there are no active reservations.
/// [title] — `null`: «Faol bronlar: N».
class ActiveReservationsCard extends ConsumerWidget {
  const ActiveReservationsCard({
    super.key,
    required this.onTap,
    this.title,
    this.dense = false,
  });

  final VoidCallback onTap;
  final String? title;

  /// Home card: tighter, without the medicine line — keeps the home list
  /// close to the height it had with a plain shortcut card.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeReservationsProvider).value ?? const [];
    final focus = focusReservation(active);
    if (focus == null) return const SizedBox.shrink();
    final ready = active
        .where((r) => r.status == ReservationStatus.ready)
        .length;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return AppCard(
      key: const ValueKey('active-reservations-card'),
      onTap: onTap,
      padding: EdgeInsets.all(dense ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EmojiBox(
                emoji: ready > 0 ? '✅' : '💊',
                color: ready > 0 ? AppColors.good : AppColors.primary,
                size: dense ? 40 : 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ??
                          context.tr(
                            uz: 'Faol bronlar: ${active.length}',
                            ru: 'Активные брони: ${active.length}',
                            en: 'Active reservations: ${active.length}',
                          ),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ready > 0
                          ? context.tr(
                              uz: 'Olib ketishga tayyor: $ready',
                              ru: 'Готово к выдаче: $ready',
                              en: 'Ready for pickup: $ready',
                            )
                          : context.tr(
                              uz: 'Dorixona tayyorlamoqda',
                              ru: 'Аптека собирает заказ',
                              en: 'The pharmacy is preparing it',
                            ),
                      style: text.bodySmall?.copyWith(
                        color: ready > 0
                            ? AppColors.readable(
                                AppColors.good,
                                theme.brightness,
                              )
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: ready > 0 ? FontWeight.w700 : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          if (!dense) ...[
            const SizedBox(height: 12),
            Text(
              [
                focus.medicine?.name ?? '—',
                if (focus.pharmacy != null) focus.pharmacy!.name,
              ].join(' · '),
              style: text.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: dense ? 10 : 8),
          ReservationSteps(reservation: focus, compact: true),
        ],
      ),
    );
  }
}
