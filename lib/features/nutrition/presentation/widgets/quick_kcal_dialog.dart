import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../data/models.dart';
import '../labels.dart';

/// Most calories in one quick entry.
const maxQuickKcal = 5000;

/// «Faqat kkal»: a name (optional) and calories, macros if known — for a
/// café meal or anything not in the catalog. `null` — cancelled.
Future<Food?> showQuickKcalDialog(BuildContext context) => showDialog<Food>(
  context: context,
  builder: (_) => const _QuickKcalDialog(),
);

class _QuickKcalDialog extends StatefulWidget {
  const _QuickKcalDialog();

  @override
  State<_QuickKcalDialog> createState() => _QuickKcalDialogState();
}

class _QuickKcalDialogState extends State<_QuickKcalDialog> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _fat, _carbs]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  double? get _kcalValue {
    final v = _num(_kcal);
    return v != null && v > 0 && v <= maxQuickKcal ? v : null;
  }

  void _save() {
    final kcal = _kcalValue;
    if (kcal == null) return;
    final typed = _name.text.trim();
    final name = typed.isEmpty
        ? {'uz': 'Tez qo‘shilgan', 'ru': 'Быстрая запись', 'en': 'Quick entry'}
        : {'uz': typed, 'ru': typed, 'en': typed};
    double macro(TextEditingController c) => (_num(c) ?? 0).clamp(0, 1000);
    Navigator.of(context).pop(
      Food.custom(
        source: FoodSource.quick,
        name: name,
        emoji: '⚡',
        kcal: kcal.roundToDouble(),
        protein: macro(_protein),
        fat: macro(_fat),
        carbs: macro(_carbs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = gramUnit(context);
    final digits = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      LengthLimitingTextInputFormatter(6),
    ];
    Widget macro(String key, TextEditingController c, String label) => Expanded(
      child: TextField(
        key: Key('nutrition-quick-$key'),
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: digits,
        decoration: InputDecoration(labelText: label, suffixText: g),
      ),
    );

    return AlertDialog(
      title: Text(
        context.tr(
          uz: '⚡ Faqat kaloriya',
          ru: '⚡ Только калории',
          en: '⚡ Just calories',
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('nutrition-quick-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: context.tr(
                  uz: 'Nima yedingiz? (ixtiyoriy)',
                  ru: 'Что съели? (необязательно)',
                  en: 'What was it? (optional)',
                ),
                hintText: context.tr(
                  uz: 'Masalan: kafedagi burger',
                  ru: 'Например: бургер в кафе',
                  en: 'E.g. a burger at a café',
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('nutrition-quick-kcal'),
              controller: _kcal,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: digits,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: context.tr(
                  uz: 'Kaloriya',
                  ru: 'Калории',
                  en: 'Calories',
                ),
                suffixText: kcalUnit(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                macro(
                  'protein',
                  _protein,
                  context.tr(uz: 'Oqsil', ru: 'Белки', en: 'Protein'),
                ),
                const SizedBox(width: AppSpacing.xs),
                macro(
                  'fat',
                  _fat,
                  context.tr(uz: 'Yog‘', ru: 'Жиры', en: 'Fat'),
                ),
                const SizedBox(width: AppSpacing.xs),
                macro(
                  'carbs',
                  _carbs,
                  context.tr(uz: 'Uglevod', ru: 'Углев.', en: 'Carbs'),
                ),
              ],
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
          key: const Key('nutrition-quick-save'),
          onPressed: _kcalValue == null ? null : _save,
          child: Text(context.tr(uz: 'Qo‘shish', ru: 'Добавить', en: 'Add')),
        ),
      ],
    );
  }
}
