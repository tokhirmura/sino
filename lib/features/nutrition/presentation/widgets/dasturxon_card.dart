import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../application/nutrition_providers.dart';
import '../../data/dasturxon.dart';
import '../../data/models.dart';
import '../labels.dart';

/// What the quick-add sheet returns: how much and into which meal.
typedef DasturxonChoice = ({
  Meal meal,
  double servings,
  HomeMeasure measure,
  double count,
});

/// «Dasturxon» (S2-5): the 12 most eaten dishes as big buttons; a tap
/// opens [showDasturxonSheet], where one tap on an amount adds it.
class DasturxonCard extends ConsumerWidget {
  const DasturxonCard({super.key, required this.onPick});

  final ValueChanged<DasturxonDish> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      key: const Key('nutrition-dasturxon'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const EmojiBox(emoji: '🫖', color: AppColors.saffron, size: 40),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        uz: 'Dasturxon',
                        ru: 'Дастархан',
                        en: 'Dastarkhan',
                      ),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      context.tr(
                        uz: 'Kosa, likopcha, dona — bir bosishda',
                        ru: 'Миска, тарелка, штука — в одно касание',
                        en: 'Bowl, plate, piece — in one tap',
                      ),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AsyncValueView(
            value: ref.watch(dasturxonProvider),
            compact: true,
            onRetry: () => ref.invalidate(dasturxonProvider),
            data: (dishes) => LayoutBuilder(
              builder: (context, c) {
                const columns = 4;
                const gap = AppSpacing.xs;
                final w = (c.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final d in dishes)
                      SizedBox(
                        width: w,
                        child: _DishButton(dish: d, onTap: () => onPick(d)),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DishButton extends StatelessWidget {
  const _DishButton({required this.dish, required this.onTap});

  final DasturxonDish dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Pressable(
      child: Material(
        color: AppColors.saffron.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          key: Key('dasturxon-${dish.item.slug}'),
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xxs,
            ),
            child: Column(
              children: [
                Text(
                  dish.food.emoji ?? '🍽️',
                  style: const TextStyle(fontSize: 30),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // One line; a long name shrinks instead of breaking a word.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _shortName(context, dish),
                    maxLines: 1,
                    style: text.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dish's short label, else the catalog name without the part in
/// brackets: «Palov (osh)» → «Palov».
String _shortName(BuildContext context, DasturxonDish d) {
  if (d.item.label.isNotEmpty) return context.trMap(d.item.label);
  final full = context.trMap(d.food.name);
  final i = full.indexOf(' (');
  return i > 0 ? full.substring(0, i) : full;
}

/// Quick add of [dish]: pick the meal, then one tap on an amount
/// («1 kosa · 280 kkal») adds it; `null` — closed.
Future<DasturxonChoice?> showDasturxonSheet(
  BuildContext context, {
  required DasturxonDish dish,
  required Meal meal,
}) => showModalBottomSheet<DasturxonChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: _DasturxonSheet(dish: dish, initialMeal: meal),
  ),
);

class _DasturxonSheet extends StatefulWidget {
  const _DasturxonSheet({required this.dish, required this.initialMeal});

  final DasturxonDish dish;
  final Meal initialMeal;

  @override
  State<_DasturxonSheet> createState() => _DasturxonSheetState();
}

class _DasturxonSheetState extends State<_DasturxonSheet> {
  late Meal _meal = widget.initialMeal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = widget.dish;
    final kcal = kcalUnit(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EmojiBox(
                emoji: d.food.emoji ?? '🍽️',
                color: AppColors.saffron,
                size: 56,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.trMap(d.food.name),
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      context.tr(
                        uz: 'Qancha yedingiz? Bosing — qo‘shiladi',
                        ru: 'Сколько съели? Нажмите — добавится',
                        en: 'How much? Tap to add',
                      ),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final m in Meal.values)
                ChoiceChip(
                  key: Key('dasturxon-meal-${m.name}'),
                  label: Text('${m.emoji} ${m.label(context)}'),
                  selected: _meal == m,
                  onSelected: (_) => setState(() => _meal = m),
                ),
            ],
          ),
          for (final m in d.item.measures) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '${measureText(context, m.measure, 1)} ≈ '
              '${formatGrams(m.grams)} ${gramUnit(context)}',
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final count in presetCounts(m.measure))
                  if (dasturxonServings(d.food, m, count: count)
                      case final servings?)
                    _AmountButton(
                      key: Key(
                        'dasturxon-add-${m.measure.key}-${countText(count)}',
                      ),
                      title: measureText(context, m.measure, count),
                      subtitle: '${(d.food.kcal * servings).round()} $kcal',
                      onTap: () => Navigator.of(context).pop((
                        meal: _meal,
                        servings: servings,
                        measure: m.measure,
                        count: count,
                      )),
                    ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr(
              uz:
                  'Gramm va kaloriya taxminiy. Shifokor maslahatini '
                  'almashtirmaydi.',
              ru:
                  'Граммы и калории приблизительные. Не заменяет '
                  'консультацию врача.',
              en:
                  'Grams and calories are estimates. Does not replace a '
                  'doctor’s advice.',
            ),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 62.5 → «62.5», 300 → «300».
String formatGrams(double g) =>
    g == g.roundToDouble() ? '${g.toInt()}' : g.toStringAsFixed(1);

class _AmountButton extends StatelessWidget {
  const _AmountButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    return Pressable(
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96, minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.readable(AppColors.primary, brightness),
                    ),
                  ),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
