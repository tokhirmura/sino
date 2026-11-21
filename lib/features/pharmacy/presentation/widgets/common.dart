import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/emoji_box.dart';
import '../../../../core/widgets/money.dart';
import '../../application/pharmacy_providers.dart';
import '../../data/models.dart';
import '../labels.dart';

/// Required on every medical screen.
class MedicalDisclaimer extends StatelessWidget {
  const MedicalDisclaimer({super.key, this.message});

  /// Extra line under the title.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      elevated: false,
      color: AppColors.amber.withValues(alpha: 0.14),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shifokor maslahatini almashtirmaydi',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  message ??
                      context.tr(
                        uz:
                            'Dorini qo‘llashdan oldin yo‘riqnomani o‘qing va '
                            'shifokor yoki farmatsevt bilan maslahatlashing.',
                        ru:
                            'Не заменяет консультацию врача. Перед приёмом '
                            'прочитайте инструкцию и посоветуйтесь с врачом '
                            'или фармацевтом.',
                        en:
                            'Does not replace a doctor’s advice. Read the '
                            'leaflet and ask a doctor or pharmacist before use.',
                      ),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Like core `Pill` (readable ink on a tinted background), but the label
/// ellipsizes — never overflows in narrow cards or wraps.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color = AppColors.primary, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    // Text / icon darkened (light) or lightened (dark) to contrast ≥ 4.5.
    final ink = AppColors.readable(color, brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      // The icon is dropped only when there is no room even for it.
      child: LayoutBuilder(
        builder: (context, box) {
          final withIcon = icon != null && box.maxWidth >= 40;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (withIcon) ...[
                Icon(icon, size: 14, color: ink),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ink,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// «Retsept bilan» / «Retseptsiz».
class RxPill extends StatelessWidget {
  const RxPill({super.key, required this.rx});

  final bool rx;

  @override
  Widget build(BuildContext context) => rx
      ? Tag(
          context.tr(uz: 'Retsept bilan', ru: 'По рецепту', en: 'Prescription'),
          color: AppColors.coral,
          icon: Icons.receipt_long_rounded,
        )
      : Tag(
          context.tr(
            uz: 'Retseptsiz',
            ru: 'Без рецепта',
            en: 'Over the counter',
          ),
          color: AppColors.good,
        );
}

/// A medicine row: category emoji, name, ingredient · form, price.
class MedicineTile extends StatelessWidget {
  const MedicineTile({
    super.key,
    required this.medicine,
    required this.onTap,
    this.price,
  });

  final Medicine medicine;
  final VoidCallback onTap;

  /// Shown instead of the reference price (e.g. the best price).
  final int? price;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final shown = price ?? medicine.priceUzs;
    final subtitle = [
      if (medicine.ingredient != null) medicine.ingredient!,
      formLabel(context, medicine.form),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            EmojiBox(
              emoji: categoryEmoji(medicine.category),
              color: categoryColor(medicine.category),
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Flexible: a long price at a large font wraps instead of
            // pushing the row past the card.
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (shown != null)
                    Text(
                      price == null
                          ? '≈ ${formatMoney(shown)}'
                          : context.tr(
                              uz: '${formatMoney(shown)} dan',
                              ru: 'от ${formatMoney(shown)}',
                              en: 'from ${formatMoney(shown)}',
                            ),
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (medicine.rx) ...[
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: AppColors.coral,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One pharmacy's price of a medicine with a «Bron qilish» button.
class OfferTile extends StatelessWidget {
  const OfferTile({super.key, required this.offer, required this.onReserve});

  final StockOffer offer;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final p = offer.pharmacy;
    final km = offer.distanceKm;
    final meta = [
      if (km != null) formatDistance(context, km),
      hoursLabel(context, p),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: offer.inStock ? 1 : 0.55,
        child: AppCard(
          padding: const EdgeInsets.all(12),
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
                          p.name,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (p.address != null)
                          Text(
                            p.address!,
                            style: text.bodySmall?.copyWith(color: muted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            style: text.bodySmall?.copyWith(color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Money(
                    offer.priceUzs,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: offer.inStock
                        ? Text(
                            context.tr(
                              uz: 'Mavjud: ${offer.stock.qty} dona',
                              ru: 'В наличии: ${offer.stock.qty} шт.',
                              en: 'In stock: ${offer.stock.qty}',
                            ),
                            style: text.bodySmall?.copyWith(
                              color: AppColors.good,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : Text(
                            context.tr(
                              uz: 'Tugagan',
                              ru: 'Нет в наличии',
                              en: 'Out of stock',
                            ),
                            style: text.bodySmall?.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  FilledButton.tonal(
                    onPressed: offer.inStock ? onReserve : null,
                    style: FilledButton.styleFrom(
                      // The theme makes filled buttons full-width.
                      minimumSize: const Size(0, 40),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      context.tr(
                        uz: 'Bron qilish',
                        ru: 'Забронировать',
                        en: 'Reserve',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showPharmacySnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Text of a [ReservationException] (or `null` for other errors).
String? reservationProblemText(BuildContext context, Object error) {
  if (error is! ReservationException) return null;
  return switch (error.problem) {
    ReservationProblem.rxRequired => context.tr(
      uz: 'Bu dori retsept bilan beriladi — retsept rasmini biriktiring.',
      ru: 'Лекарство отпускается по рецепту — прикрепите фото рецепта.',
      en: 'This medicine needs a prescription — attach a photo of it.',
    ),
    ReservationProblem.outOfStock => context.tr(
      uz: 'Bu dorixonada dori tugagan.',
      ru: 'В этой аптеке лекарство закончилось.',
      en: 'This pharmacy is out of stock.',
    ),
    ReservationProblem.alreadyActive => context.tr(
      uz: 'Bu dori shu dorixonada allaqachon bron qilingan.',
      ru: 'Это лекарство уже забронировано в этой аптеке.',
      en: 'You already reserved this medicine at this pharmacy.',
    ),
    ReservationProblem.notCancellable => context.tr(
      uz: 'Bu bronni bekor qilib bo‘lmaydi.',
      ru: 'Эту бронь нельзя отменить.',
      en: 'This reservation can’t be cancelled.',
    ),
  };
}
