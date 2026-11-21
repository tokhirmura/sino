import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/money.dart';
import '../../../core/widgets/section_title.dart';
import '../application/pharmacy_providers.dart';
import '../data/external_launcher.dart';
import '../data/models.dart';
import '../data/rx_photo.dart';
import 'labels.dart';
import 'widgets/common.dart';
import 'widgets/reserve_sheet.dart';

/// «Bronlarim»: active reservations with a live status (realtime / the
/// simulated pharmacy in fake mode), then the history.
class ReservationsScreen extends ConsumerWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tell the user when the pharmacy has prepared a reservation.
    ref.listen(reservationsProvider, (prev, next) {
      final before = {
        for (final r in prev?.value ?? const <Reservation>[]) r.id: r.status,
      };
      for (final r in next.value ?? const <Reservation>[]) {
        if (before[r.id] == ReservationStatus.pending &&
            r.status == ReservationStatus.ready) {
          showPharmacySnack(
            context,
            context.tr(
              uz: '${r.medicine?.name ?? ''} olib ketishga tayyor!',
              ru: '${r.medicine?.name ?? ''} готово к выдаче!',
              en: '${r.medicine?.name ?? ''} is ready for pickup!',
            ),
          );
        }
      }
    });

    final reservations = ref.watch(reservationsProvider);
    return AppScaffold(
      title: context.tr(
        uz: 'Bronlarim',
        ru: 'Мои брони',
        en: 'My reservations',
      ),
      body: AsyncValueView(
        value: reservations,
        onRetry: () => ref.invalidate(reservationsProvider),
        loading: () => const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: 8),
          child: SkeletonList(count: 3, itemHeight: 140),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              emoji: '🧾',
              title: context.tr(
                uz: 'Hali bron yo‘q',
                ru: 'Броней пока нет',
                en: 'No reservations yet',
              ),
              message: context.tr(
                uz: 'Dorini toping va yaqin dorixonada bron qiling.',
                ru: 'Найдите лекарство и забронируйте в ближайшей аптеке.',
                en: 'Find a medicine and reserve it at a nearby pharmacy.',
              ),
              action: FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.search_rounded),
                label: Text(
                  context.tr(
                    uz: 'Dori qidirish',
                    ru: 'Найти лекарство',
                    en: 'Find a medicine',
                  ),
                ),
              ),
            );
          }
          final active = [
            for (final r in list)
              if (r.status.isActive) r,
          ];
          final history = [
            for (final r in list)
              if (!r.status.isActive) r,
          ];
          return ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            children: [
              if (active.isNotEmpty) ...[
                SectionTitle(
                  context.tr(uz: 'Faol', ru: 'Активные', en: 'Active'),
                ),
                for (final r in active) ReservationCard(reservation: r),
              ],
              if (history.isNotEmpty) ...[
                SectionTitle(
                  context.tr(uz: 'Tarix', ru: 'История', en: 'History'),
                ),
                for (final r in history) ReservationCard(reservation: r),
              ],
            ],
          );
        },
      ),
    );
  }
}

class ReservationCard extends ConsumerWidget {
  const ReservationCard({super.key, required this.reservation});

  final Reservation reservation;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.tr(
            uz: 'Bronni bekor qilasizmi?',
            ru: 'Отменить бронь?',
            en: 'Cancel the reservation?',
          ),
        ),
        content: Text(reservation.medicine?.name ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr(uz: 'Yo‘q', ru: 'Нет', en: 'No')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              context.tr(uz: 'Bekor qilish', ru: 'Отменить', en: 'Cancel it'),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(reservationsProvider.notifier).cancel(reservation.id);
    } catch (e) {
      if (context.mounted) {
        showPharmacySnack(
          context,
          reservationProblemText(context, e) ?? errorMessage(context, e),
        );
      }
    }
  }

  Future<void> _openMap(BuildContext context, WidgetRef ref, Pharmacy p) async {
    final ok = await ref.read(pharmacyLauncherProvider)(pharmacyMapsUri(p));
    if (!ok && context.mounted) {
      showPharmacySnack(
        context,
        context.tr(
          uz: 'Xaritani ochib bo‘lmadi',
          ru: 'Не удалось открыть карту',
          en: 'Couldn’t open the map',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final r = reservation;
    final p = r.pharmacy;
    final photo = ref.watch(rxPhotosProvider)[r.id];
    final members = ref.watch(familyMembersProvider).value ?? const [];
    String? memberName;
    for (final f in members) {
      if (f.id == r.forMemberId) memberName = f.name;
    }
    final price = ref.watch(medicineOffersProvider(r.medicineId)).value;
    int? priceUzs;
    for (final o in price ?? const <StockOffer>[]) {
      if (o.pharmacy.id == r.pharmacyId) priceUzs = o.priceUzs;
    }
    final saving = r.id.startsWith('pending-');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.medicine?.name ?? '—',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p != null)
                        Text(
                          [
                            p.name,
                            if (p.address != null) p.address!,
                          ].join(' · '),
                          style: text.bodySmall?.copyWith(color: muted),
                        ),
                    ],
                  ),
                ),
                if (priceUzs != null) ...[
                  const SizedBox(width: 8),
                  Money(
                    priceUzs,
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tag(
                  statusLabel(context, r.status),
                  color: statusColor(r.status),
                  icon: statusIcon(r.status),
                ),
                if (memberName != null)
                  Tag(
                    memberName,
                    color: AppColors.violet,
                    icon: Icons.person_rounded,
                  ),
                if (r.rxAttached)
                  Tag(
                    context.tr(uz: 'Retsept', ru: 'Рецепт', en: 'Prescription'),
                    color: AppColors.coral,
                    icon: Icons.receipt_long_rounded,
                  ),
                if (r.createdAt != null)
                  Text(
                    formatDateTime(r.createdAt!),
                    style: text.bodySmall?.copyWith(color: muted),
                  ),
              ],
            ),
            if (r.status == ReservationStatus.pending) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(minHeight: 4),
              ),
              const SizedBox(height: 6),
              Text(
                saving
                    ? context.tr(
                        uz: 'Yuborilmoqda…',
                        ru: 'Отправляем…',
                        en: 'Sending…',
                      )
                    : context.tr(
                        uz:
                            'Dorixona buyurtmani yig‘moqda — tayyor bo‘lganda '
                            'shu yerda ko‘rasiz.',
                        ru: 'Аптека собирает заказ — статус обновится здесь.',
                        en:
                            'The pharmacy is preparing it — the status will '
                            'update here.',
                      ),
                style: text.bodySmall,
              ),
            ],
            if (r.status == ReservationStatus.ready) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(
                  uz: 'Dorixonaga boring va bron haqida ayting. To‘lov joyida.',
                  ru: 'Приходите в аптеку и назовите бронь. Оплата на месте.',
                  en:
                      'Go to the pharmacy and mention your reservation. '
                      'Pay there.',
                ),
                style: text.bodySmall?.copyWith(
                  color: AppColors.readable(
                    AppColors.good,
                    Theme.of(context).brightness,
                  ),
                ),
              ),
            ],
            if (photo != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: RxThumbnail(path: photo, size: 300),
                    ),
                  ),
                ),
                child: RxThumbnail(path: photo),
              ),
            ],
            if (r.status.isActive && !saving) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  if (p != null)
                    TextButton.icon(
                      onPressed: () => _openMap(context, ref, p),
                      icon: const Icon(Icons.directions_rounded),
                      label: Text(
                        context.tr(
                          uz: 'Yo‘nalish',
                          ru: 'Маршрут',
                          en: 'Directions',
                        ),
                      ),
                    ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () => _cancel(context, ref),
                    child: Text(
                      context.tr(
                        uz: 'Bekor qilish',
                        ru: 'Отменить',
                        en: 'Cancel',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
