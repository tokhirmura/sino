import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/add_food_providers.dart';
import '../application/nutrition_math.dart';
import '../data/ingredients.dart';
import '../data/models.dart';
import '../data/nutrition_repository.dart';
import 'labels.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/add_food_parts.dart';

/// Ready-made texts for the «example» chips, in the app language.
Map<String, String> _examples(BuildContext context) => {
  'palov': context.tr(
    uz:
        'guruch 500 g\nsabzi 500 g\nqo‘y go‘shti 400 g\nyog‘ 120 g\n'
        'piyoz 2 ta\nno‘xat 100 g\nziravorlar',
    ru:
        'рис 500 г\nморковь 500 г\nбаранина 400 г\nмасло 120 г\n'
        'лук 2 шт\nнут 100 г\nспеции',
    en:
        'rice 500 g\ncarrot 500 g\nlamb 400 g\noil 120 g\n'
        'onion 2 pcs\nchickpeas 100 g\nspices',
  ),
  'omlet': context.tr(
    uz: 'tuxum 3 ta\nsut 50 ml\nsariyog‘ 10 g\npomidor 1 ta',
    ru: 'яйца 3 шт\nмолоко 50 мл\nсливочное масло 10 г\nпомидор 1 шт',
    en: 'eggs 3 pcs\nmilk 50 ml\nbutter 10 g\ntomato 1 pc',
  ),
  'salat': context.tr(
    uz: 'pomidor 2 ta\nbodring 2 ta\npiyoz 1 ta\nyog‘ 1 osh qoshiq',
    ru: 'помидор 2 шт\nогурец 2 шт\nлук 1 шт\nмасло 1 ст. л.',
    en: 'tomato 2 pcs\ncucumber 2 pcs\nonion 1 pc\noil 1 tbsp',
  ),
};

/// «O‘zim pishirdim»: the user writes what went into the pot («guruch
/// 500 g, sabzi 2 ta …»), the app reads the ingredients, sums calories and
/// macros, divides by portions. The recipe can be saved and cooked again.
/// Pops a [FoodChoice] with one portion as the food.
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({super.key, required this.meal});

  final Meal meal;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  final _name = TextEditingController();
  final _text = TextEditingController();
  int _portions = 4;
  double _eaten = 1;
  bool _keep = true;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  void _load(SavedRecipe r) {
    _name.text = r.name;
    _text.text = r.text;
    setState(() => _portions = r.portions);
  }

  void _append(String line) {
    final t = _text.text.trimRight();
    _text.text = t.isEmpty ? line : '$t\n$line';
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
  }

  Future<void> _pickIngredient(List<Ingredient> all) async {
    final ing = await showModalBottomSheet<Ingredient>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: _IngredientPicker(all: all),
      ),
    );
    if (ing == null || !mounted) return;
    final amount = ing.pieceGrams != null
        ? context.tr(uz: '1 ta', ru: '1 шт', en: '1 pc')
        : '100 ${gramUnit(context)}';
    _append('${context.trMap(ing.name)} $amount');
  }

  String get _title {
    final t = _name.text.trim();
    return t.isEmpty
        ? context.tr(uz: 'Uy taomi', ru: 'Домашнее блюдо', en: 'Homemade dish')
        : t;
  }

  Future<void> _add(RecipeSummary s) async {
    final food = recipeFood(name: _title, summary: s);
    if (_keep) {
      await ref
          .read(myRecipesProvider.notifier)
          .save(
            SavedRecipe(
              name: _title,
              text: _text.text.trim(),
              portions: _portions,
            ),
          );
    }
    if (mounted) {
      Navigator.of(context).pop(FoodChoice(food, widget.meal, _eaten));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(
        uz: 'O‘zim pishirdim',
        ru: 'Своё блюдо',
        en: 'Homemade dish',
      ),
      subtitle: '${widget.meal.emoji} ${widget.meal.label(context)}',
      body: AsyncValueView(
        value: ref.watch(ingredientsProvider),
        onRetry: () => ref.invalidate(ingredientsProvider),
        data: (all) => _body(context, all),
      ),
    );
  }

  Widget _body(BuildContext context, List<Ingredient> all) {
    final text = Theme.of(context).textTheme;
    final parse = parseRecipe(_text.text, all);
    final summary = summarizeRecipe(parse.lines, _portions);
    final saved = ref.watch(myRecipesProvider);
    final ready = parse.lines.isNotEmpty && summary.total.kcal > 0;
    final eatenKcal = (summary.perPortion.kcal * _eaten).round();

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 32),
      children: [
        if (saved.isNotEmpty) ...[
          Text(
            context.tr(
              uz: 'Mening retseptlarim',
              ru: 'Мои рецепты',
              en: 'My recipes',
            ),
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in saved)
                InputChip(
                  key: Key('nutrition-my-recipe-${r.name}'),
                  avatar: Text(r.emoji),
                  label: Text(r.name),
                  onPressed: () => _load(r),
                  deleteButtonTooltipMessage: context.tr(
                    uz: 'O‘chirish',
                    ru: 'Удалить',
                    en: 'Remove',
                  ),
                  onDeleted: () =>
                      ref.read(myRecipesProvider.notifier).remove(r.name),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('nutrition-recipe-name'),
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr(
                    uz: 'Taom nomi',
                    ru: 'Название блюда',
                    en: 'Dish name',
                  ),
                  hintText: context.tr(
                    uz: 'Masalan: uy palovi',
                    ru: 'Например: домашний плов',
                    en: 'E.g. home plov',
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('nutrition-recipe-text'),
                controller: _text,
                minLines: 4,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: context.tr(
                    uz: 'Nimalar soldingiz?',
                    ru: 'Что положили?',
                    en: 'What did you put in?',
                  ),
                  alignLabelWithHint: true,
                  hintText: context.tr(
                    uz: 'guruch 500 g\nsabzi 2 ta\ngo‘sht 300 g\nyog‘ 3 osh qoshiq',
                    ru: 'рис 500 г\nморковь 2 шт\nговядина 300 г\nмасло 3 ст. л.',
                    en: 'rice 500 g\ncarrot 2 pcs\nbeef 300 g\noil 3 tbsp',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ActionChip(
                    key: const Key('nutrition-recipe-add-ingredient'),
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      context.tr(
                        uz: 'Masalliq',
                        ru: 'Ингредиент',
                        en: 'Ingredient',
                      ),
                    ),
                    onPressed: () => _pickIngredient(all),
                  ),
                  if (_text.text.trim().isEmpty)
                    for (final e in _examples(context).entries)
                      ActionChip(
                        key: Key('nutrition-recipe-example-${e.key}'),
                        label: Text(switch (e.key) {
                          'palov' => context.tr(
                            uz: 'Misol: palov',
                            ru: 'Пример: плов',
                            en: 'Example: plov',
                          ),
                          'omlet' => context.tr(
                            uz: 'Omlet',
                            ru: 'Омлет',
                            en: 'Omelette',
                          ),
                          _ => context.tr(
                            uz: 'Salat',
                            ru: 'Салат',
                            en: 'Salad',
                          ),
                        }),
                        onPressed: () {
                          if (_name.text.trim().isEmpty) {
                            _name.text = switch (e.key) {
                              'palov' => context.tr(
                                uz: 'Uy palovi',
                                ru: 'Домашний плов',
                                en: 'Home plov',
                              ),
                              'omlet' => context.tr(
                                uz: 'Omlet',
                                ru: 'Омлет',
                                en: 'Omelette',
                              ),
                              _ => context.tr(
                                uz: 'Achchiq-chuchuk',
                                ru: 'Салат из овощей',
                                en: 'Fresh salad',
                              ),
                            };
                          }
                          _text.text = e.value;
                          setState(
                            () => _portions = e.key == 'palov'
                                ? 6
                                : e.key == 'omlet'
                                ? 1
                                : 2,
                          );
                        },
                      ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        _Ingredients(parse: parse),
        const SizedBox(height: AppSpacing.cardGap),
        AppCard(
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Stepper(
                keyName: 'portions',
                label: context.tr(
                  uz: 'Necha porsiya chiqdi?',
                  ru: 'Сколько порций вышло?',
                  en: 'How many portions?',
                ),
                value: '$_portions',
                onMinus: _portions > 1
                    ? () => setState(() => _portions--)
                    : null,
                onPlus: _portions < maxRecipePortions
                    ? () => setState(() => _portions++)
                    : null,
              ),
              _Stepper(
                keyName: 'eaten',
                label: context.tr(
                  uz: 'Siz yedingiz (porsiya)',
                  ru: 'Вы съели (порций)',
                  en: 'You ate (portions)',
                ),
                value: formatServings(_eaten),
                onMinus: _eaten > servingsStep
                    ? () => setState(
                        () => _eaten = snapServings(_eaten - servingsStep),
                      )
                    : null,
                onPlus: _eaten < maxServings
                    ? () => setState(
                        () => _eaten = snapServings(_eaten + servingsStep),
                      )
                    : null,
              ),
              if (ready) ...[
                const Divider(height: AppSpacing.lg),
                Text(
                  context.tr(
                    uz:
                        '1 porsiya ≈ ${summary.portionGrams.round()} g '
                        '(xom masalliqlar)',
                    ru:
                        '1 порция ≈ ${summary.portionGrams.round()} г '
                        '(сырые продукты)',
                    en:
                        '1 portion ≈ ${summary.portionGrams.round()} g '
                        '(raw ingredients)',
                  ),
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  nutrientText(
                    context,
                    kcal: summary.perPortion.kcal,
                    protein: summary.perPortion.protein,
                    fat: summary.perPortion.fat,
                    carbs: summary.perPortion.carbs,
                  ),
                  key: const Key('nutrition-recipe-portion'),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (summary.fatty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Pill(
                    context.tr(
                      uz:
                          'Yog‘li chiqdi: kaloriyaning '
                          '${(summary.fatShare * 100).round()}% yog‘dan. '
                          'Keyingi safar yog‘ni kamroq solib ko‘ring.',
                      ru:
                          'Жирновато: ${(summary.fatShare * 100).round()}% '
                          'калорий из жира. В следующий раз попробуйте '
                          'меньше масла.',
                      en:
                          'Quite fatty: ${(summary.fatShare * 100).round()}% '
                          'of calories from fat. Try less oil next time.',
                    ),
                    key: const Key('nutrition-recipe-fatty'),
                    color: AppColors.coral,
                    icon: Icons.water_drop_outlined,
                    wrap: true,
                  ),
                ],
              ],
            ],
          ),
        ),
        CheckboxListTile(
          key: const Key('nutrition-recipe-keep'),
          contentPadding: EdgeInsets.zero,
          value: _keep,
          onChanged: (v) => setState(() => _keep = v ?? true),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            context.tr(
              uz: 'Retseptlarimga saqlash',
              ru: 'Сохранить в мои рецепты',
              en: 'Save to my recipes',
            ),
          ),
        ),
        PrimaryButton(
          key: const Key('nutrition-recipe-add'),
          label: ready
              ? context.tr(
                  uz: 'Qo‘shish · $eatenKcal kkal',
                  ru: 'Добавить · $eatenKcal ккал',
                  en: 'Add · $eatenKcal kcal',
                )
              : context.tr(
                  uz: 'Masalliqlarni yozing',
                  ru: 'Напишите ингредиенты',
                  en: 'Write the ingredients',
                ),
          icon: Icons.add_rounded,
          onPressed: ready ? () => _add(summary) : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.tr(
            uz:
                'Hisob taxminiy: xom masalliqlar bo‘yicha. Shifokor '
                'maslahatini almashtirmaydi.',
            ru:
                'Расчёт приблизительный, по сырым продуктам. Не заменяет '
                'консультацию врача.',
            en:
                'An estimate from raw ingredients. Does not replace a '
                'doctor’s advice.',
          ),
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// What the parser understood, line by line, and what it did not.
class _Ingredients extends StatelessWidget {
  const _Ingredients({required this.parse});

  final RecipeParse parse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final g = gramUnit(context);
    if (parse.lines.isEmpty && parse.unknown.isEmpty) {
      return Text(
        context.tr(
          uz:
              'Har bir masalliqni yangi qatorda yoki vergul bilan yozing: '
              'miqdori va birligi (g, kg, ta, qoshiq, stakan).',
          ru:
              'Пишите каждый продукт с новой строки или через запятую: '
              'количество и единица (г, кг, шт, ложка, стакан).',
          en:
              'One ingredient per line or comma-separated: amount and '
              'unit (g, kg, pcs, spoon, cup).',
        ),
        style: text.bodySmall,
      );
    }
    return AppCard(
      key: const Key('nutrition-recipe-lines'),
      animate: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final l in parse.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    l.ingredient.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      context.trMap(l.ingredient.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                  if (l.guessed)
                    Tooltip(
                      message: context.tr(
                        uz: 'Miqdor taxminiy — matnda aniqlashtiring',
                        ru: 'Количество примерное — уточните в тексте',
                        en: 'Amount is a guess — set it in the text',
                      ),
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 16,
                        color: AppColors.readable(
                          AppColors.saffron,
                          theme.brightness,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.xxs),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${l.grams.round()} $g',
                      textAlign: TextAlign.end,
                      style: text.bodyMedium,
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    child: Text(
                      '${l.kcal.round()} ${kcalUnit(context)}',
                      textAlign: TextAlign.end,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (parse.unknown.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Pill(
              context.tr(
                uz: 'Tanilmadi: ${parse.unknown.join(', ')}',
                ru: 'Не распознано: ${parse.unknown.join(', ')}',
                en: 'Not recognized: ${parse.unknown.join(', ')}',
              ),
              key: const Key('nutrition-recipe-unknown'),
              color: AppColors.coral,
              icon: Icons.help_outline_rounded,
              wrap: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String keyName;
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: text.titleSmall)),
        IconButton.filledTonal(
          key: Key('nutrition-recipe-$keyName-minus'),
          tooltip: context.tr(uz: 'Kamaytirish', ru: 'Меньше', en: 'Less'),
          onPressed: onMinus,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value,
            key: Key('nutrition-recipe-$keyName'),
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filledTonal(
          key: Key('nutrition-recipe-$keyName-plus'),
          tooltip: context.tr(uz: 'Ko‘paytirish', ru: 'Больше', en: 'More'),
          onPressed: onPlus,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _IngredientPicker extends StatefulWidget {
  const _IngredientPicker({required this.all});

  final List<Ingredient> all;

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = normalizeFoodText(_query);
    final found = [
      for (final i in widget.all)
        if (q.isEmpty ||
            i.name.values.any((n) => normalizeFoodText('$n').contains(q)))
          i,
    ];
    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: context.tr(
                uz: 'Masalliqni qidiring',
                ru: 'Найти продукт',
                en: 'Find an ingredient',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: ListView.builder(
              itemCount: found.length,
              itemBuilder: (context, i) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  found[i].emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(context.trMap(found[i].name)),
                subtitle: Text(
                  context.tr(
                    uz: '100 g — ${found[i].kcal.round()} kkal',
                    ru: '100 г — ${found[i].kcal.round()} ккал',
                    en: '100 g — ${found[i].kcal.round()} kcal',
                  ),
                ),
                onTap: () => Navigator.of(context).pop(found[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
