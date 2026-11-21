import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/home_meds_providers.dart';
import '../application/pharmacy_providers.dart';
import '../data/home_meds_repository.dart';
import '../data/models.dart';
import '../data/pharmacy_repository.dart';
import 'labels.dart';
import 'pharmacy_paths.dart';
import 'widgets/common.dart';
import 'widgets/motion.dart';

/// Opens the barcode scanner and returns the code (`null` — cancelled).
/// A provider so tests can scan without a camera.
final homeMedsScannerProvider =
    Provider<Future<String?> Function(BuildContext context)>(
      (ref) =>
          (context) => context.push<String>(PharmacyPaths.scan),
    );

/// «Uy dorixonasi»: medicines at home with expiry dates, a warning
/// 30 days ahead, re-order → `/pharmacy?q=<name>`.
class HomeMedsScreen extends ConsumerWidget {
  const HomeMedsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(homeMedsProvider);
    return AppScaffold(
      title: context.tr(
        uz: 'Uy dorixonasi',
        ru: 'Домашняя аптечка',
        en: 'Home medicine cabinet',
      ),
      padding: EdgeInsets.zero,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home-meds-add',
        onPressed: () => showHomeMedSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr(uz: 'Qo‘shish', ru: 'Добавить', en: 'Add')),
      ),
      body: AsyncValueView(
        value: meds,
        onRetry: () => ref.invalidate(homeMedsProvider),
        loading: () => const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: SkeletonLoader(count: 4),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              emoji: '🏠',
              title: context.tr(
                uz: 'Uy dorixonasi bo‘sh',
                ru: 'Аптечка пуста',
                en: 'Your cabinet is empty',
              ),
              message: context.tr(
                uz:
                    'Uydagi dorilarni qo‘shing — muddati tugashidan 30 kun '
                    'oldin ogohlantiramiz.',
                ru:
                    'Добавьте лекарства из дома — предупредим за 30 дней до '
                    'конца срока годности.',
                en:
                    'Add the medicines you have at home — we’ll warn you 30 '
                    'days before they expire.',
              ),
              actionLabel: context.tr(
                uz: 'Dori qo‘shish',
                ru: 'Добавить лекарство',
                en: 'Add a medicine',
              ),
              actionIcon: Icons.add_rounded,
              onAction: () => showHomeMedSheet(context),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const _Summary(),
              const SizedBox(height: AppSpacing.cardGap),
              MedicalDisclaimer(
                message: context.tr(
                  uz: 'Muddati o‘tgan dorini ichmang — dorixonaga topshiring.',
                  ru: 'Не принимайте просроченные лекарства — сдайте их в аптеку.',
                  en: 'Don’t take expired medicines — hand them in to a pharmacy.',
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              for (final (i, m) in list.indexed)
                HomeMedTile(
                  key: ValueKey('home-med-${m.id}'),
                  med: m,
                  index: i,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeMedsSummaryProvider).value;
    if (s == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: StatTile(
            value: '${s.total}',
            label: context.tr(uz: 'Jami', ru: 'Всего', en: 'Total'),
            emoji: '💊',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            value: '${s.soon}',
            label: context.tr(
              uz: '30 kunda',
              ru: 'За 30 дней',
              en: 'In 30 days',
            ),
            emoji: '⏳',
            color: AppColors.saffron,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            value: '${s.expired}',
            label: context.tr(uz: 'O‘tgan', ru: 'Истёк', en: 'Expired'),
            emoji: '⚠️',
            color: AppColors.garnet,
          ),
        ),
      ],
    );
  }
}

/// «12.03.2027».
String formatExpiry(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Expiry status badge. Expired / soon — solid and loud (white text on a
/// darkened fill, ≥ 4.5:1), fine / no date — a soft tag.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.med, required this.now});

  final HomeMed med;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final state = expiryState(med, now);
    final days = daysUntilExpiry(med, now);
    final key = ValueKey('expiry-${state.name}');
    switch (state) {
      case ExpiryState.ok:
        return Tag(
          key: key,
          context.tr(uz: 'Yaroqli', ru: 'Годен', en: 'Valid'),
          color: AppColors.good,
          icon: Icons.verified_rounded,
        );
      case ExpiryState.unknown:
        return Tag(
          key: key,
          context.tr(
            uz: 'Muddati kiritilmagan',
            ru: 'Срок не указан',
            en: 'No expiry date',
          ),
          color: AppColors.sky,
          icon: Icons.help_outline_rounded,
        );
      case ExpiryState.expired || ExpiryState.soon:
        final expired = state == ExpiryState.expired;
        final fill = AppColors.readable(
          expired ? AppColors.garnet : AppColors.saffron,
          Brightness.light,
        );
        final label = expired
            ? context.tr(uz: 'Muddati o‘tgan', ru: 'Срок истёк', en: 'Expired')
            : days == 0
            ? context.tr(
                uz: 'Bugun tugaydi',
                ru: 'Истекает сегодня',
                en: 'Expires today',
              )
            : context.tr(
                uz: '$days kun qoldi',
                ru: 'Осталось дней: $days',
                en: '$days days left',
              );
        return Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: LayoutBuilder(
            builder: (context, box) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (box.maxWidth >= 48) ...[
                  Icon(
                    expired
                        ? Icons.error_rounded
                        : Icons.hourglass_bottom_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

/// One home medicine: name, count, expiry date and badge, notes, and
/// «Qayta buyurtma» / «Buyurtma berish» → pharmacy search. Tap — edit.
class HomeMedTile extends ConsumerWidget {
  const HomeMedTile({super.key, required this.med, this.index});

  final HomeMed med;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final now = ref.watch(homeMedsClockProvider)();
    final catalog = ref.watch(medicinesByIdProvider).value;
    final medicine = med.medicineId == null ? null : catalog?[med.medicineId];
    final state = expiryState(med, now);
    // Nothing usable left → «order»; otherwise a re-order for later.
    final needsOrder =
        med.quantity == 0 ||
        state == ExpiryState.expired ||
        state == ExpiryState.soon;
    final saving = med.id.startsWith('pending-');

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        animate: index == null,
        onTap: saving ? null : () => showHomeMedSheet(context, med: med),
        padding: const EdgeInsets.all(14),
        borderColor: state == ExpiryState.expired
            ? AppColors.garnet.withValues(alpha: 0.5)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmojiBox(
                  emoji: medicine == null
                      ? '💊'
                      : categoryEmoji(medicine.category),
                  color: medicine == null
                      ? AppColors.primary
                      : categoryColor(medicine.category),
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          context.tr(
                            uz: '${med.quantity} dona',
                            ru: '${med.quantity} шт.',
                            en: '${med.quantity} pcs',
                          ),
                          if (med.expiryDate != null)
                            context.tr(
                              uz: '${formatExpiry(med.expiryDate!)} gacha',
                              ru: 'до ${formatExpiry(med.expiryDate!)}',
                              en: 'until ${formatExpiry(med.expiryDate!)}',
                            ),
                        ].join(' · '),
                        style: text.bodySmall?.copyWith(color: muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((med.notes ?? '').isNotEmpty)
                        Text(
                          med.notes!,
                          style: text.bodySmall?.copyWith(
                            color: muted,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ExpiryBadge(med: med, now: now),
                if (!saving)
                  needsOrder
                      ? FilledButton.tonalIcon(
                          key: const ValueKey('home-med-order'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _order(context),
                          icon: const Icon(Icons.shopping_cart_rounded),
                          label: Text(
                            context.tr(
                              uz: 'Buyurtma berish',
                              ru: 'Заказать',
                              en: 'Order now',
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          key: const ValueKey('home-med-reorder'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _order(context),
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(
                            context.tr(
                              uz: 'Qayta buyurtma',
                              ru: 'Заказать снова',
                              en: 'Re-order',
                            ),
                          ),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
    return index == null ? tile : tile.staggerIn(index!);
  }

  /// The pharmacy tab with the search filled in (the `/pharmacy?q=`
  /// contract).
  void _order(BuildContext context) =>
      context.go(AppRoutes.pharmacySearch(med.name));
}

/// Add ([med] == null, optionally [medicine] preselected) or edit a home
/// medicine.
Future<void> showHomeMedSheet(
  BuildContext context, {
  HomeMed? med,
  Medicine? medicine,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => HomeMedSheet(med: med, medicine: medicine),
);

class HomeMedSheet extends ConsumerStatefulWidget {
  const HomeMedSheet({super.key, this.med, this.medicine});

  final HomeMed? med;
  final Medicine? medicine;

  @override
  ConsumerState<HomeMedSheet> createState() => _HomeMedSheetState();
}

class _HomeMedSheetState extends ConsumerState<HomeMedSheet> {
  late final _name = TextEditingController(
    text: widget.med?.name ?? widget.medicine?.name ?? '',
  );
  late final _notes = TextEditingController(text: widget.med?.notes ?? '');
  late String? _medicineId = widget.med?.medicineId ?? widget.medicine?.id;
  late DateTime? _expiry = widget.med?.expiryDate;
  late int _quantity = widget.med?.quantity ?? 1;
  String _query = '';
  bool _saving = false;
  String? _error;

  bool get _editing => widget.med != null;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _pick(Medicine m) {
    _name.value = TextEditingValue(
      text: m.name,
      selection: TextSelection.collapsed(offset: m.name.length),
    );
    setState(() {
      _medicineId = m.id;
      _query = '';
      _error = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _scan() async {
    final code = await ref.read(homeMedsScannerProvider)(context);
    if (code == null || code.trim().isEmpty || !mounted) return;
    try {
      final m = await ref.read(medicineByBarcodeProvider(code.trim()).future);
      if (!mounted) return;
      if (m != null) {
        _pick(m);
      } else {
        setState(
          () => _error = context.tr(
            uz: 'Shtrix-kod bo‘yicha dori topilmadi — nomini yozing.',
            ru: 'Лекарство по штрих-коду не найдено — введите название.',
            en: 'No medicine for this barcode — type the name.',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    }
  }

  Future<void> _pickDate() async {
    final now = ref.read(homeMedsClockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: context.tr(
        uz: 'Yaroqlilik muddati',
        ru: 'Срок годности',
        en: 'Expiry date',
      ),
    );
    if (picked != null && mounted) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    final notifier = ref.read(homeMedsProvider.notifier);
    final draft = HomeMed(
      id: widget.med?.id ?? '',
      medicineId: _medicineId,
      name: _name.text.trim(),
      expiryDate: _expiry,
      quantity: _quantity,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: widget.med?.createdAt,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final savedText = context.tr(
      uz: 'Uy dorixonasiga saqlandi: ${draft.name}',
      ru: 'Сохранено в аптечке: ${draft.name}',
      en: 'Saved to your cabinet: ${draft.name}',
    );
    try {
      if (_editing) {
        await notifier.edit(draft);
      } else {
        await notifier.add(draft);
      }
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(savedText)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _problemText(context, e);
      });
    }
  }

  Future<void> _delete() async {
    final med = widget.med;
    if (med == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final text = context.tr(
      uz: 'O‘chirildi: ${med.name}',
      ru: 'Удалено: ${med.name}',
      en: 'Removed: ${med.name}',
    );
    final undo = context.tr(uz: 'Qaytarish', ru: 'Вернуть', en: 'Undo');
    final notifier = ref.read(homeMedsProvider.notifier);
    try {
      final removed = await notifier.remove(med.id);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(text),
            action: removed == null
                ? null
                : SnackBarAction(
                    label: undo,
                    onPressed: () => notifier.add(removed),
                  ),
          ),
        );
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    }
  }

  static String _problemText(BuildContext context, Object e) => switch (e) {
    HomeMedException(problem: HomeMedProblem.emptyName) => context.tr(
      uz: 'Dori nomini kiriting',
      ru: 'Введите название лекарства',
      en: 'Enter the medicine name',
    ),
    HomeMedException(problem: HomeMedProblem.badQuantity) => context.tr(
      uz: 'Soni 0 dan 999 gacha',
      ru: 'Количество от 0 до 999',
      en: 'Quantity must be 0–999',
    ),
    _ => errorMessage(context, e),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final catalog = ref.watch(medicinesCatalogProvider).value ?? const [];
    final suggestions = _query.trim().length < 2
        ? const <Medicine>[]
        : searchMedicines(catalog, _query).take(5).toList();
    final now = ref.watch(homeMedsClockProvider)();
    final preview = HomeMed(id: '', name: '', expiryDate: _expiry);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _editing
                  ? context.tr(
                      uz: 'Dorini tahrirlash',
                      ru: 'Изменить лекарство',
                      en: 'Edit medicine',
                    )
                  : context.tr(
                      uz: 'Uy dorixonasiga qo‘shish',
                      ru: 'Добавить в аптечку',
                      en: 'Add to your cabinet',
                    ),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('home-med-name'),
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr(
                  uz: 'Dori nomi yoki shtrix-kod',
                  ru: 'Название или штрих-код',
                  en: 'Name or barcode',
                ),
                prefixIcon: const Icon(Icons.medication_rounded),
                suffixIcon: IconButton(
                  tooltip: context.tr(
                    uz: 'Shtrix-kodni skanerlash',
                    ru: 'Сканировать штрих-код',
                    en: 'Scan barcode',
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: _scan,
                ),
              ),
              onChanged: (v) => setState(() {
                _query = v;
                // Typed by hand: no longer the catalog entry.
                _medicineId = null;
                _error = null;
              }),
            ),
            if (_medicineId != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.readable(AppColors.good, theme.brightness),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr(
                        uz: 'Katalogdan tanlandi',
                        ru: 'Выбрано из каталога',
                        en: 'Picked from the catalog',
                      ),
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            for (final m in suggestions)
              ListTile(
                key: ValueKey('home-med-suggestion-${m.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Text(
                  categoryEmoji(m.category),
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: m.ingredient == null
                    ? null
                    : Text(
                        m.ingredient!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: const Icon(Icons.add_circle_outline_rounded),
                onTap: () => _pick(m),
              ),
            const SizedBox(height: 14),
            Text(
              context.tr(
                uz: 'Yaroqlilik muddati',
                ru: 'Срок годности',
                en: 'Expiry date',
              ),
              style: text.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('home-med-date'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    _expiry == null
                        ? context.tr(
                            uz: 'Sanani tanlang',
                            ru: 'Выбрать дату',
                            en: 'Pick a date',
                          )
                        : formatExpiry(_expiry!),
                  ),
                ),
                if (_expiry != null) ExpiryBadge(med: preview, now: now),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(uz: 'Soni', ru: 'Количество', en: 'Quantity'),
                    style: text.labelLarge,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: context.tr(uz: 'Kamroq', ru: 'Меньше', en: 'Less'),
                  onPressed: _quantity > 0
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '$_quantity',
                    key: const ValueKey('home-med-qty'),
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: context.tr(uz: 'Ko‘proq', ru: 'Больше', en: 'More'),
                  onPressed: _quantity < 999
                      ? () => setState(() => _quantity++)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.tr(
                  uz: 'Izoh (ixtiyoriy)',
                  ru: 'Заметка (необязательно)',
                  en: 'Note (optional)',
                ),
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: text.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              key: const ValueKey('home-med-save'),
              label: context.tr(uz: 'Saqlash', ru: 'Сохранить', en: 'Save'),
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _save,
            ),
            if (_editing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(
                  context.tr(uz: 'O‘chirish', ru: 'Удалить', en: 'Delete'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
