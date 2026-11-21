import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/pharmacy_providers.dart';
import '../data/models.dart';
import '../data/pharmacy_repository.dart';
import 'labels.dart';
import 'pharmacy_paths.dart';
import 'widgets/common.dart';
import 'widgets/ready_celebration.dart';
import 'widgets/active_reservation_card.dart';

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
    final active = ref.watch(activeReservationsProvider).value ?? const [];
    final ready = active
        .where((r) => r.status == ReservationStatus.ready)
        .length;
    final theme = Theme.of(context);
    return ReadyCelebrationHost(
      child: Scaffold(
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              GradientHeader(
                title: context.tr(uz: 'Dorixona', ru: 'Аптека', en: 'Pharmacy'),
                subtitle: context.tr(
                  uz: 'Toping, narxlarni solishtiring, bron qiling',
                  ru: 'Найдите, сравните цены, забронируйте',
                  en: 'Find, compare prices, reserve',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                ),
                child: Column(
                  children: [
                    _searchField(theme),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            onDark: true,
                            value: '${catalog.value?.length ?? '—'}',
                            label: context.tr(
                              uz: 'Dorilar',
                              ru: 'Лекарства',
                              en: 'Medicines',
                            ),
                            icon: Icons.medication_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatTile(
                            onDark: true,
                            value: '${active.length}',
                            label: ready > 0
                                ? context.tr(
                                    uz: 'Tayyor: $ready',
                                    ru: 'Готово: $ready',
                                    en: 'Ready: $ready',
                                  )
                                : context.tr(
                                    uz: 'Faol bronlar',
                                    ru: 'Активные брони',
                                    en: 'Active orders',
                                  ),
                            icon: Icons.shopping_bag_rounded,
                            onTap: () =>
                                context.push(PharmacyPaths.reservations),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: AsyncValueView(
                  value: catalog,
                  compact: true,
                  onRetry: () => ref.invalidate(medicinesCatalogProvider),
                  loading: () => const SkeletonLoader(count: 6),
                  data: (list) => _results(context, list),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(ThemeData theme) => TextField(
    controller: _search,
    onChanged: _onChanged,
    textInputAction: TextInputAction.search,
    onSubmitted: (v) => _setQuery(v.trim()),
    style: TextStyle(color: theme.colorScheme.onSurface),
    decoration: InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surface,
      hintText: context.tr(
        uz: 'Dori, ta’sir qiluvchi modda yoki shtrix-kod',
        ru: 'Лекарство, вещество или штрих-код',
        en: 'Medicine, ingredient or barcode',
      ),
      prefixIcon: Icon(
        Icons.search_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      suffixIcon: IconTheme.merge(
        data: IconThemeData(color: theme.colorScheme.onSurfaceVariant),
        child: Row(
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
  );

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            actionLabel: context.tr(
              uz: 'Skanerlash',
              ru: 'Сканировать',
              en: 'Scan',
            ),
            actionIcon: Icons.qr_code_scanner_rounded,
            onAction: _scan,
          )
        else
          for (final (i, m) in found.indexed)
            MedicineTile(
              // Keyed: a new search or category replays the entrance.
              key: ValueKey('med-${m.id}-$_query-$_category'),
              index: i,
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

class _ActiveReservationsBanner extends StatelessWidget {
  const _ActiveReservationsBanner();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ActiveReservationsCard(
      onTap: () => context.push(PharmacyPaths.reservations),
    ),
  );
}
