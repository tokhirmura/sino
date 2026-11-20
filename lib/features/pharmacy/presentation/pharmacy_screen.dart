import 'dart:async';

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
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_title.dart';
import '../application/pharmacy_providers.dart';
import '../data/models.dart';
import '../data/pharmacy_repository.dart';
import 'labels.dart';
import 'pharmacy_paths.dart';
import 'widgets/common.dart';

/// «Dorixona» tab: search by name, active ingredient, symptom or barcode
/// (typed or scanned), category chips, active reservations.
/// [initialQuery] comes from the `/pharmacy?q=<query>` contract.
class PharmacyScreen extends ConsumerStatefulWidget {
  const PharmacyScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends ConsumerState<PharmacyScreen> {
  late final TextEditingController _search;
  Timer? _debounce;
  String _query = '';
  String? _category;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery?.trim() ?? '';
    _search = TextEditingController(text: _query);
  }

  @override
  void didUpdateWidget(PharmacyScreen old) {
    super.didUpdateWidget(old);
    // The tab keeps its state: a new `?q=` must still replace the query.
    final q = widget.initialQuery?.trim();
    if (q != null && q != old.initialQuery?.trim()) _setQuery(q);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    _debounce?.cancel();
    _search.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    setState(() {
      _query = q;
      _category = null;
    });
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _scan() async {
    final code = await context.push<String>(PharmacyPaths.scan);
    if (code == null || code.trim().isEmpty || !mounted) return;
    try {
      final m = await ref.read(medicineByBarcodeProvider(code.trim()).future);
      if (!mounted) return;
      if (m != null) {
        context.push(PharmacyPaths.medicine(m.id));
      } else {
        _setQuery(code.trim());
        showPharmacySnack(
          context,
          context.tr(
            uz: 'Shtrix-kod bo‘yicha dori topilmadi',
            ru: 'Лекарство по штрих-коду не найдено',
            en: 'No medicine found for this barcode',
          ),
        );
      }
    } catch (e) {
      if (mounted) showPharmacySnack(context, errorMessage(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(medicinesCatalogProvider);
    return AppScaffold(
      title: context.tr(uz: 'Dorixona', ru: 'Аптека', en: 'Pharmacy'),
      padding: EdgeInsets.zero,
      actions: [
        IconButton(
          tooltip: context.tr(
            uz: 'Dorixonalar xaritasi',
            ru: 'Карта аптек',
            en: 'Pharmacy map',
          ),
          icon: const Icon(Icons.map_outlined),
          onPressed: () => context.push(PharmacyPaths.pharmacies),
        ),
        const _ReservationsAction(),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _setQuery(v.trim()),
              decoration: InputDecoration(
                hintText: context.tr(
                  uz: 'Dori, ta’sir qiluvchi modda yoki shtrix-kod',
                  ru: 'Лекарство, вещество или штрих-код',
                  en: 'Medicine, ingredient or barcode',
                ),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_search.text.isNotEmpty)
                      IconButton(
                        tooltip: context.tr(
                          uz: 'Tozalash',
                          ru: 'Очистить',
                          en: 'Clear',
                        ),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _setQuery(''),
                      ),
                    IconButton(
                      tooltip: context.tr(
                        uz: 'Shtrix-kodni skanerlash',
                        ru: 'Сканировать штрих-код',
                        en: 'Scan barcode',
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      onPressed: _scan,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: catalog,
              onRetry: () => ref.invalidate(medicinesCatalogProvider),
              loading: () => const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: SkeletonList(count: 6),
              ),
              data: (list) => _results(context, list),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, List<Medicine> all) {
    final searching = _query.isNotEmpty;
    final found = searching
        ? searchMedicines(all, _query)
        : [
            for (final m in all)
              if (_category == null || m.category == _category) m,
          ];
    final categories = [
      for (final c in medicineCategories)
        if (all.any((m) => m.category == c)) c,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (!searching) ...[
          const _ActiveReservationsBanner(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      context.tr(uz: 'Hammasi', ru: 'Все', en: 'All'),
                    ),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Text(categoryEmoji(c)),
                      label: Text(categoryLabel(context, c)),
                      selected: _category == c,
                      onSelected: (_) =>
                          setState(() => _category = _category == c ? null : c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        SectionTitle(
          searching
              ? context.tr(
                  uz: 'Natijalar: ${found.length}',
                  ru: 'Найдено: ${found.length}',
                  en: 'Results: ${found.length}',
                )
              : _category == null
              ? context.tr(
                  uz: 'Barcha dorilar',
                  ru: 'Все лекарства',
                  en: 'All medicines',
                )
              : categoryLabel(context, _category),
        ),
        if (found.isEmpty)
          EmptyState(
            emoji: '🔍',
            title: context.tr(
              uz: 'Hech narsa topilmadi',
              ru: 'Ничего не найдено',
              en: 'Nothing found',
            ),
            message: context.tr(
              uz:
                  'Boshqa nom, ta’sir qiluvchi modda yoki belgini yozib ko‘ring '
                  'yoki qutidagi shtrix-kodni skanerlang.',
              ru:
                  'Попробуйте другое название, вещество или симптом либо '
                  'отсканируйте штрих-код на упаковке.',
              en:
                  'Try another name, ingredient or symptom, or scan the '
                  'barcode on the box.',
            ),
            action: OutlinedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                context.tr(uz: 'Skanerlash', ru: 'Сканировать', en: 'Scan'),
              ),
            ),
          )
        else
          for (final m in found)
            MedicineTile(
              medicine: m,
              onTap: () => context.push(PharmacyPaths.medicine(m.id)),
            ),
      ],
    );
  }
}

/// App bar button to «Bronlarim» with the active count.
class _ReservationsAction extends ConsumerWidget {
  const _ReservationsAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeReservationsProvider).value?.length ?? 0;
    return IconButton(
      tooltip: context.tr(
        uz: 'Bronlarim',
        ru: 'Мои брони',
        en: 'My reservations',
      ),
      onPressed: () => context.push(PharmacyPaths.reservations),
      icon: Badge(
        isLabelVisible: active > 0,
        label: Text('$active'),
        child: const Icon(Icons.receipt_long_outlined),
      ),
    );
  }
}

class _ActiveReservationsBanner extends ConsumerWidget {
  const _ActiveReservationsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeReservationsProvider).value ?? const [];
    if (active.isEmpty) return const SizedBox.shrink();
    final ready = active
        .where((r) => r.status == ReservationStatus.ready)
        .length;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => context.push(PharmacyPaths.reservations),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            EmojiBox(
              emoji: ready > 0 ? '✅' : '⏳',
              color: ready > 0 ? AppColors.good : AppColors.amber,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      uz: 'Faol bronlar: ${active.length}',
                      ru: 'Активные брони: ${active.length}',
                      en: 'Active reservations: ${active.length}',
                    ),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
