import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/emoji_box.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/money.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/section_title.dart';
import '../application/pharmacy_providers.dart';
import '../data/models.dart';
import 'labels.dart';
import 'pharmacy_paths.dart';
import 'widgets/common.dart';
import 'widgets/reserve_sheet.dart';

/// Medicine card: description, warning, disclaimer, prices in pharmacies
/// (by price or distance) with «Bron qilish», generic analogs.
class MedicineScreen extends ConsumerStatefulWidget {
  const MedicineScreen({super.key, required this.medicineId});

  final String medicineId;

  @override
  ConsumerState<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends ConsumerState<MedicineScreen> {
  OfferSort _sort = OfferSort.price;

  Future<void> _reserve(StockOffer offer) async {
    final saved = await showReserveSheet(context, offer);
    if (saved == null || !mounted) return;
    showPharmacySnack(
      context,
      context.tr(
        uz: 'Bron qilindi: ${offer.medicine.name}',
        ru: 'Забронировано: ${offer.medicine.name}',
        en: 'Reserved: ${offer.medicine.name}',
      ),
      action: SnackBarAction(
        label: context.tr(
          uz: 'Bronlarim',
          ru: 'Мои брони',
          en: 'My reservations',
        ),
        onPressed: () => context.push(PharmacyPaths.reservations),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(medicinesByIdProvider);
    return AppScaffold(
      title: context.tr(uz: 'Dori', ru: 'Лекарство', en: 'Medicine'),
      body: AsyncValueView(
        value: medicines,
        onRetry: () => ref.invalidate(medicinesCatalogProvider),
        data: (byId) {
          final m = byId[widget.medicineId];
          if (m == null) {
            return EmptyState(
              emoji: '💊',
              title: context.tr(
                uz: 'Dori topilmadi',
                ru: 'Лекарство не найдено',
                en: 'Medicine not found',
              ),
            );
          }
          return _body(context, m);
        },
      ),
    );
  }

  Widget _body(BuildContext context, Medicine m) {
    final text = Theme.of(context).textTheme;
    final offersProvider = medicineOffersProvider(m.id);
    final offers = ref.watch(offersProvider);
    final hasLocation = ref.watch(userLocationProvider).value != null;
    final analogs = ref.watch(analogsProvider(m.id));
    final description = context.trMap(m.description);
    final warning = context.trMap(m.warning);

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmojiBox(
                emoji: categoryEmoji(m.category),
                color: categoryColor(m.category),
                size: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (m.ingredient != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          uz: 'Ta’sir qiluvchi modda: ${m.ingredient}',
                          ru: 'Действующее вещество: ${m.ingredient}',
                          en: 'Active ingredient: ${m.ingredient}',
                        ),
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        RxPill(rx: m.rx),
                        if (m.form != null)
                          Pill(
                            formLabel(context, m.form),
                            color: AppColors.sky,
                          ),
                        if (m.category != null)
                          Pill(
                            categoryLabel(context, m.category),
                            color: categoryColor(m.category),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const MedicalDisclaimer(),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          SectionTitle(context.tr(uz: 'Tavsif', ru: 'Описание', en: 'About')),
          Text(description, style: text.bodyMedium),
        ],
        if (warning.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            elevated: false,
            color: AppColors.danger.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(uz: 'Diqqat', ru: 'Внимание', en: 'Caution'),
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(warning, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (m.rx) ...[
          const SizedBox(height: 12),
          Text(
            context.tr(
              uz:
                  'Bron qilish uchun retsept rasmini biriktirasiz — '
                  'dorixonada asl nusxasini ko‘rsating.',
              ru:
                  'Для брони прикрепите фото рецепта — в аптеке покажите '
                  'оригинал.',
              en:
                  'Attach a photo of the prescription to reserve — show the '
                  'original at the pharmacy.',
            ),
            style: text.bodySmall?.copyWith(color: AppColors.coral),
          ),
        ],
        const SizedBox(height: 8),
        SectionTitle(
          context.tr(
            uz: 'Dorixonalardagi narxlar',
            ru: 'Цены в аптеках',
            en: 'Prices in pharmacies',
          ),
        ),
        SegmentedButton<OfferSort>(
          segments: [
            ButtonSegment(
              value: OfferSort.price,
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                context.tr(uz: 'Arzon', ru: 'Дешевле', en: 'Cheapest'),
              ),
            ),
            ButtonSegment(
              value: OfferSort.distance,
              enabled: hasLocation,
              icon: const Icon(Icons.near_me_outlined),
              label: Text(context.tr(uz: 'Yaqin', ru: 'Ближе', en: 'Nearest')),
            ),
          ],
          selected: {_sort},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _sort = s.first),
        ),
        const SizedBox(height: 10),
        AsyncValueView(
          value: offers,
          compact: true,
          onRetry: () => ref.invalidate(offersProvider),
          loading: () => const SkeletonList(count: 3, itemHeight: 110),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                context.tr(
                  uz: 'Hozircha hech bir dorixonada yo‘q.',
                  ru: 'Пока нет ни в одной аптеке.',
                  en: 'Not available in any pharmacy yet.',
                ),
              );
            }
            final sorted = sortOffers(list, _sort);
            final inStock = list.where((o) => o.inStock).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (inStock.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      context.tr(
                        uz:
                            '${inStock.length} ta dorixonada bor, eng arzoni '
                            '${formatMoney(sortOffers(inStock, OfferSort.price).first.priceUzs)}',
                        ru:
                            'Есть в ${inStock.length} аптеках, дешевле всего '
                            '${formatMoney(sortOffers(inStock, OfferSort.price).first.priceUzs)}',
                        en:
                            'In stock at ${inStock.length} pharmacies, from '
                            '${formatMoney(sortOffers(inStock, OfferSort.price).first.priceUzs)}',
                      ),
                      style: text.bodySmall,
                    ),
                  ),
                for (final o in sorted)
                  OfferTile(offer: o, onReserve: () => _reserve(o)),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        SectionTitle(context.tr(uz: 'Analoglar', ru: 'Аналоги', en: 'Analogs')),
        Text(
          context.tr(
            uz:
                'Ta’sir qiluvchi moddasi bir xil dorilar. Almashtirishdan oldin '
                'shifokor yoki farmatsevt bilan maslahatlashing.',
            ru:
                'Лекарства с тем же действующим веществом. Перед заменой '
                'посоветуйтесь с врачом или фармацевтом.',
            en:
                'Medicines with the same active ingredient. Ask a doctor or '
                'pharmacist before switching.',
          ),
          style: text.bodySmall,
        ),
        const SizedBox(height: 10),
        AsyncValueView(
          value: analogs,
          compact: true,
          onRetry: () => ref.invalidate(analogsProvider(m.id)),
          data: (list) => list.isEmpty
              ? Text(
                  context.tr(
                    uz: 'Katalogda analoglar yo‘q.',
                    ru: 'В каталоге нет аналогов.',
                    en: 'No analogs in the catalog.',
                  ),
                )
              : Column(
                  children: [
                    for (final a in list)
                      MedicineTile(
                        medicine: a,
                        price: ref.watch(bestPriceProvider(a.id)).value,
                        onTap: () => context.pushReplacement(
                          PharmacyPaths.medicine(a.id),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
