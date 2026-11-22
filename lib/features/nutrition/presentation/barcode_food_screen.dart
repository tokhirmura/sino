import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/add_food_providers.dart';
import '../data/models.dart';
import '../data/products.dart';
import 'labels.dart';
import 'widgets/add_food_parts.dart';
import 'widgets/add_food_sheet.dart';

/// No camera plugin under `flutter test` (and on desktop / web).
bool get _cameraAvailable =>
    !kIsWeb &&
    (Platform.isAndroid || Platform.isIOS) &&
    !Platform.environment.containsKey('FLUTTER_TEST');

/// «Shtrix-kod»: scan a store product (or type its code, or pick it from
/// popular products) → its label per 100 g with a sugar / fat / salt
/// «traffic light» → choose how much (a pack, half, grams) → added.
/// Unknown code → the user types the label once, it is remembered.
/// Pops a [FoodChoice].
class BarcodeFoodScreen extends ConsumerStatefulWidget {
  const BarcodeFoodScreen({super.key, required this.meal, this.useCamera});

  final Meal meal;

  /// `null` — when the device has a camera plugin.
  final bool? useCamera;

  @override
  ConsumerState<BarcodeFoodScreen> createState() => _BarcodeFoodScreenState();
}

class _BarcodeFoodScreenState extends ConsumerState<BarcodeFoodScreen> {
  Product? _product;

  /// Last lookup: code + its result (`null` product = not found).
  ({String code, AsyncValue<Product?> result})? _lookup;
  String _query = '';

  Future<void> _find(String code) async {
    final c = code.trim();
    if (c.isEmpty || _lookup?.result.isLoading == true) return;
    setState(() => _lookup = (code: c, result: const AsyncLoading()));
    try {
      final p = await ref.read(productsRepositoryProvider).byBarcode(c);
      if (!mounted) return;
      setState(() {
        _lookup = (code: c, result: AsyncData(p));
        if (p != null) _product = p;
      });
    } catch (e, st) {
      if (mounted) {
        setState(() => _lookup = (code: c, result: AsyncError(e, st)));
      }
    }
  }

  Future<void> _typeCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _CodeDialog(),
    );
    if (code != null && mounted) await _find(code);
  }

  Future<void> _enterLabel(String? code) async {
    final p = await showDialog<Product>(
      context: context,
      builder: (_) => _LabelDialog(barcode: code),
    );
    if (p == null || !mounted) return;
    await ref.read(productsRepositoryProvider).remember(p);
    ref.invalidate(popularProductsProvider);
    if (mounted) setState(() => _product = p);
  }

  void _back() => setState(() {
    _product = null;
    _lookup = null;
  });

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return PopScope(
      canPop: product == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AppScaffold(
        title: context.tr(uz: 'Shtrix-kod', ru: 'Штрих-код', en: 'Barcode'),
        subtitle: '${widget.meal.emoji} ${widget.meal.label(context)}',
        body: product != null
            ? _ProductView(
                product: product,
                onAdd: (food) =>
                    Navigator.of(context).pop(FoodChoice(food, widget.meal, 1)),
                onAnother: _back,
              )
            : _scanView(context),
      ),
    );
  }

  Widget _scanView(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lookup = _lookup;
    final popular = ref.watch(popularProductsProvider);
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 32),
      children: [
        _ScannerBox(
          enabled: widget.useCamera ?? _cameraAvailable,
          onCode: _find,
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          key: const Key('nutrition-barcode-type'),
          onPressed: _typeCode,
          icon: const Icon(Icons.keyboard_rounded),
          label: Text(
            context.tr(
              uz: 'Kodni qo‘lda kiritish',
              ru: 'Ввести код вручную',
              en: 'Type the code',
            ),
          ),
        ),
        if (lookup != null) ...[
          const SizedBox(height: AppSpacing.sm),
          lookup.result.when(
            loading: () =>
                const SkeletonLoader(count: 1, kind: SkeletonKind.list),
            error: (e, _) => ErrorView(
              error: e,
              compact: true,
              onRetry: () => _find(lookup.code),
            ),
            data: (p) => p != null
                ? const SizedBox.shrink()
                : AppCard(
                    key: const Key('nutrition-barcode-not-found'),
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr(
                            uz: '«${lookup.code}» topilmadi',
                            ru: '«${lookup.code}» не найден',
                            en: '“${lookup.code}” not found',
                          ),
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          context.tr(
                            uz:
                                'Qadoqdagi yorliqdan 100 g uchun kaloriyani '
                                'kiriting — keyingi safar o‘zi taniladi.',
                            ru:
                                'Перепишите калории на 100 г с этикетки — '
                                'в следующий раз товар узнается сам.',
                            en:
                                'Copy calories per 100 g from the label — '
                                'next time it will be recognized.',
                          ),
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton.tonalIcon(
                          key: const Key('nutrition-barcode-enter-label'),
                          onPressed: () => _enterLabel(lookup.code),
                          icon: const Icon(Icons.edit_note_rounded),
                          label: Text(
                            context.tr(
                              uz: 'Yorliqdan kiritish',
                              ru: 'Ввести с этикетки',
                              en: 'Enter from the label',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.tr(
            uz: 'Mashhur mahsulotlar',
            ru: 'Популярные товары',
            en: 'Popular products',
          ),
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: const Key('nutrition-product-search'),
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: context.tr(
              uz: 'Masalan: Rollton, non, cola',
              ru: 'Например: Роллтон, хлеб, кола',
              en: 'E.g. Rollton, bread, cola',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AsyncValueView(
          value: popular,
          compact: true,
          onRetry: () => ref.invalidate(popularProductsProvider),
          data: (all) {
            final found = searchProducts(all, _query);
            return Column(
              children: [
                for (final p in found)
                  ListTile(
                    key: Key('nutrition-product-${p.slug ?? p.barcode}'),
                    contentPadding: EdgeInsets.zero,
                    leading: EmojiBox(
                      emoji: p.emoji,
                      color: AppColors.sky,
                      size: 44,
                    ),
                    title: Text(context.trMap(p.name)),
                    subtitle: Text(_packText(context, p)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => setState(() => _product = p),
                  ),
                if (found.isEmpty)
                  TextButton.icon(
                    onPressed: () => _enterLabel(null),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(
                      context.tr(
                        uz: 'Topilmadi — yorliqdan kiritish',
                        ru: 'Нет в списке — ввести с этикетки',
                        en: 'Not listed — enter from the label',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _unit(BuildContext context, Product p) =>
    p.liquid ? context.tr(uz: 'ml', ru: 'мл', en: 'ml') : gramUnit(context);

/// «60 g · 449 kkal / 100 g».
String _packText(BuildContext context, Product p) {
  final u = _unit(context, p);
  final per = '${p.kcal.round()} ${kcalUnit(context)} / 100 $u';
  final pack = p.package;
  return pack == null ? per : '${pack.round()} $u · $per';
}

/// Camera window with a frame; reports the first EAN / UPC it sees.
class _ScannerBox extends StatefulWidget {
  const _ScannerBox({required this.enabled, required this.onCode});

  final bool enabled;
  final ValueChanged<String> onCode;

  @override
  State<_ScannerBox> createState() => _ScannerBoxState();
}

class _ScannerBoxState extends State<_ScannerBox> {
  MobileScannerController? _controller;
  String? _last;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _controller = MobileScannerController(
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hint = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏷️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr(
                uz: 'Kamera mavjud emas — kodni qo‘lda kiriting',
                ru: 'Камера недоступна — введите код вручную',
                en: 'Camera unavailable — type the code',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: 200,
        child: ColoredBox(
          color: AppColors.ink,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controller == null)
                hint
              else ...[
                MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final v = b.rawValue;
                      // The camera reports the same code many times a second.
                      if (v != null && v.isNotEmpty && v != _last) {
                        _last = v;
                        HapticFeedback.selectionClick();
                        widget.onCode(v);
                        return;
                      }
                    }
                  },
                  errorBuilder: (_, _) => hint,
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 3),
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Text(
                    context.tr(
                      uz: 'Shtrix-kodni ramkaga to‘g‘rilang',
                      ru: 'Наведите рамку на штрих-код',
                      en: 'Point the frame at the barcode',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductView extends StatefulWidget {
  const _ProductView({
    required this.product,
    required this.onAdd,
    required this.onAnother,
  });

  final Product product;
  final ValueChanged<Food> onAdd;
  final VoidCallback onAnother;

  @override
  State<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends State<_ProductView> {
  late double _amount = _presets.first;
  final _custom = TextEditingController();

  List<double> get _presets {
    final pack = widget.product.package;
    if (pack == null || pack <= 0) return const [100, 50, 200];
    return {pack, pack / 2, 100.0}.toList();
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String _presetLabel(BuildContext context, double a) {
    final u = _unit(context, widget.product);
    final pack = widget.product.package;
    final grams = '${a.round()} $u';
    if (pack != null && a == pack) {
      return context.tr(
        uz: '1 qadoq · $grams',
        ru: '1 упаковка · $grams',
        en: '1 pack · $grams',
      );
    }
    if (pack != null && a == pack / 2) {
      return context.tr(
        uz: '½ qadoq · $grams',
        ru: '½ упаковки · $grams',
        en: '½ pack · $grams',
      );
    }
    return grams;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final u = _unit(context, p);
    final food = p.toFood(_amount);
    final flags = productFlags(p);

    return ListView(
      key: const Key('nutrition-product-view'),
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  EmojiBox(emoji: p.emoji, color: AppColors.sky, size: 56),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.trMap(p.name),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(_packText(context, p), style: text.bodySmall),
                        if (p.barcode != null)
                          Text(p.barcode!, style: text.bodySmall),
                      ],
                    ),
                  ),
                  if (p.nutriscore != null) _NutriScore(grade: p.nutriscore!),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in flags) _flagPill(context, f),
                  Pill(
                    switch (p.origin) {
                      ProductOrigin.local => context.tr(
                        uz: 'Taxminiy ma’lumot',
                        ru: 'Примерные данные',
                        en: 'Typical values',
                      ),
                      ProductOrigin.internet => 'Open Food Facts',
                      ProductOrigin.user => context.tr(
                        uz: 'Siz kiritgansiz',
                        ru: 'Введено вами',
                        en: 'Entered by you',
                      ),
                    },
                    color: AppColors.primary,
                    icon: Icons.info_outline_rounded,
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              Text(
                context.tr(uz: '100 $u da', ru: 'В 100 $u', en: 'Per 100 $u'),
                style: text.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                nutrientText(
                  context,
                  kcal: p.kcal,
                  protein: p.protein,
                  fat: p.fat,
                  carbs: p.carbs,
                ),
                style: text.bodyMedium,
              ),
              if (p.sugar != null || p.salt != null)
                Text(
                  [
                    if (p.sugar != null)
                      context.tr(
                        uz: 'shakar ${p.sugar!.toStringAsFixed(1)} g',
                        ru: 'сахар ${p.sugar!.toStringAsFixed(1)} г',
                        en: 'sugar ${p.sugar!.toStringAsFixed(1)} g',
                      ),
                    if (p.salt != null)
                      context.tr(
                        uz: 'tuz ${p.salt!.toStringAsFixed(1)} g',
                        ru: 'соль ${p.salt!.toStringAsFixed(1)} г',
                        en: 'salt ${p.salt!.toStringAsFixed(1)} g',
                      ),
                  ].join(' · '),
                  style: text.bodySmall,
                ),
              if (p.ingredients != null)
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      context.tr(
                        uz: 'Tarkibi',
                        ru: 'Состав',
                        en: 'Ingredients',
                      ),
                      style: text.labelLarge,
                    ),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(p.ingredients!, style: text.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        Text(
          context.tr(
            uz: 'Qancha yedingiz?',
            ru: 'Сколько съели?',
            en: 'How much did you have?',
          ),
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in _presets)
              ChoiceChip(
                key: Key('nutrition-product-amount-${a.round()}'),
                label: Text(_presetLabel(context, a)),
                selected: _amount == a && _custom.text.isEmpty,
                onSelected: (_) => setState(() {
                  _custom.clear();
                  _amount = a;
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: const Key('nutrition-product-custom'),
          controller: _custom,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          onChanged: (v) {
            final n = double.tryParse(v);
            setState(() {
              if (n != null && n > 0) _amount = n;
              if (v.isEmpty) _amount = _presets.first;
            });
          },
          decoration: InputDecoration(
            labelText: context.tr(
              uz: 'Yoki aniq miqdor',
              ru: 'Или точное количество',
              en: 'Or the exact amount',
            ),
            suffixText: u,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        NutrientLine(
          food: food,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        PrimaryButton(
          key: const Key('nutrition-product-add'),
          label: context.tr(
            uz: 'Qo‘shish · ${food.kcal.round()} kkal',
            ru: 'Добавить · ${food.kcal.round()} ккал',
            en: 'Add · ${food.kcal.round()} kcal',
          ),
          icon: Icons.add_rounded,
          onPressed: () => widget.onAdd(food),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          onPressed: widget.onAnother,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text(
            context.tr(
              uz: 'Boshqa mahsulot',
              ru: 'Другой товар',
              en: 'Another product',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.tr(
            uz:
                'Qadoqdagi ma’lumot farq qilishi mumkin. Shifokor '
                'maslahatini almashtirmaydi.',
            ru:
                'Данные на упаковке могут отличаться. Не заменяет '
                'консультацию врача.',
            en: 'The pack may differ. Does not replace a doctor’s advice.',
          ),
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }

  Widget _flagPill(BuildContext context, ProductFlag f) => switch (f) {
    ProductFlag.sugar => Pill(
      context.tr(uz: 'Shakar ko‘p', ru: 'Много сахара', en: 'High sugar'),
      key: const Key('nutrition-flag-sugar'),
      color: AppColors.coral,
      icon: Icons.warning_amber_rounded,
    ),
    ProductFlag.fat => Pill(
      context.tr(uz: 'Yog‘ ko‘p', ru: 'Много жира', en: 'High fat'),
      key: const Key('nutrition-flag-fat'),
      color: AppColors.coral,
      icon: Icons.warning_amber_rounded,
    ),
    ProductFlag.salt => Pill(
      context.tr(uz: 'Tuz ko‘p', ru: 'Много соли', en: 'High salt'),
      key: const Key('nutrition-flag-salt'),
      color: AppColors.coral,
      icon: Icons.warning_amber_rounded,
    ),
    ProductFlag.light => Pill(
      context.tr(uz: 'Yengil', ru: 'Лёгкий', en: 'Light'),
      key: const Key('nutrition-flag-light'),
      color: AppColors.good,
      icon: Icons.eco_rounded,
    ),
  };
}

/// Nutri-Score letter: A–B good, C so-so, D–E poor.
class _NutriScore extends StatelessWidget {
  const _NutriScore({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      'a' || 'b' => AppColors.good,
      'c' => AppColors.saffron,
      _ => AppColors.coral,
    };
    return Tooltip(
      message: 'Nutri-Score',
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          grade.toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr(uz: 'Shtrix-kod', ru: 'Штрих-код', en: 'Barcode')),
    content: TextField(
      key: const Key('nutrition-barcode-field'),
      controller: _code,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(14),
      ],
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(hintText: '4780000000000'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr(uz: 'Bekor', ru: 'Отмена', en: 'Cancel')),
      ),
      FilledButton(
        key: const Key('nutrition-barcode-find'),
        onPressed: isBarcode(_code.text)
            ? () => Navigator.of(context).pop(_code.text.trim())
            : null,
        child: Text(context.tr(uz: 'Topish', ru: 'Найти', en: 'Find')),
      ),
    ],
  );
}

/// The label of an unknown product: name, kcal per 100 g, macros, pack.
class _LabelDialog extends StatefulWidget {
  const _LabelDialog({this.barcode});

  final String? barcode;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();
  final _pack = TextEditingController();
  bool _liquid = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _kcal.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _fat, _carbs, _pack]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_n(_kcal) ?? -1) >= 0 &&
      (_n(_kcal) ?? 0) <= 950;

  void _save() {
    final name = _name.text.trim();
    double m(TextEditingController c) => (_n(c) ?? 0).clamp(0, 100).toDouble();
    Navigator.of(context).pop(
      Product(
        barcodes: [if (widget.barcode != null) widget.barcode!],
        name: {'uz': name, 'ru': name, 'en': name},
        emoji: _liquid ? '🧃' : '🛒',
        liquid: _liquid,
        package: _n(_pack),
        kcal: _n(_kcal)!,
        protein: m(_protein),
        fat: m(_fat),
        carbs: m(_carbs),
        origin: ProductOrigin.user,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _liquid
        ? context.tr(uz: 'ml', ru: 'мл', en: 'ml')
        : gramUnit(context);
    final digits = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      LengthLimitingTextInputFormatter(6),
    ];
    Widget num(
      String key,
      TextEditingController c,
      String label, {
      String? suffix,
    }) => TextField(
      key: Key('nutrition-label-$key'),
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: digits,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );

    return AlertDialog(
      title: Text(
        context.tr(
          uz: 'Yorliqdan kiritish',
          ru: 'Данные с этикетки',
          en: 'From the label',
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('nutrition-label-name'),
              controller: _name,
              maxLength: 50,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.tr(
                  uz: 'Mahsulot nomi',
                  ru: 'Название товара',
                  en: 'Product name',
                ),
                counterText: '',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _liquid,
              onChanged: (v) => setState(() => _liquid = v),
              title: Text(
                context.tr(
                  uz: 'Ichimlik (ml)',
                  ru: 'Напиток (мл)',
                  en: 'Drink (ml)',
                ),
              ),
            ),
            num(
              'kcal',
              _kcal,
              context.tr(
                uz: 'Kaloriya 100 $u da',
                ru: 'Калории в 100 $u',
                en: 'Calories per 100 $u',
              ),
              suffix: kcalUnit(context),
            ),
            Row(
              children: [
                Expanded(
                  child: num(
                    'protein',
                    _protein,
                    context.tr(uz: 'Oqsil', ru: 'Белки', en: 'Protein'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: num(
                    'fat',
                    _fat,
                    context.tr(uz: 'Yog‘', ru: 'Жиры', en: 'Fat'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: num(
                    'carbs',
                    _carbs,
                    context.tr(uz: 'Uglevod', ru: 'Углев.', en: 'Carbs'),
                  ),
                ),
              ],
            ),
            num(
              'pack',
              _pack,
              context.tr(
                uz: 'Qadoqda (ixtiyoriy)',
                ru: 'В упаковке (необязательно)',
                en: 'In the pack (optional)',
              ),
              suffix: u,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr(uz: 'Bekor', ru: 'Отмена', en: 'Cancel')),
        ),
        FilledButton(
          key: const Key('nutrition-label-save'),
          onPressed: _valid ? _save : null,
          child: Text(context.tr(uz: 'Saqlash', ru: 'Сохранить', en: 'Save')),
        ),
      ],
    );
  }
}
