import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/emoji_box.dart';
import '../../application/nutrition_math.dart';
import '../../application/nutrition_providers.dart';
import '../../data/models.dart';
import '../labels.dart';

/// One meal of the day: header with kcal total and «+», then the logs.
class MealSection extends StatelessWidget {
  const MealSection({
    super.key,
    required this.meal,
    required this.logs,
    required this.onAdd,
    required this.onServings,
    required this.onRemove,
  });

  final Meal meal;
  final List<FoodLog> logs;
  final VoidCallback onAdd;
  final void Function(FoodLog log, double servings) onServings;
  final ValueChanged<FoodLog> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final kcal = totalsOf(logs).kcal.round();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(meal.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meal.label(context),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (kcal > 0)
                Text(
                  '$kcal ${kcalUnit(context)}',
                  style: text.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              IconButton(
                key: Key('nutrition-add-${meal.name}'),
                tooltip: context.tr(
                  uz: 'Ovqat qo‘shish',
                  ru: 'Добавить еду',
                  en: 'Add food',
                ),
                onPressed: onAdd,
                icon: Icon(Icons.add_circle_rounded, color: meal.color),
              ),
            ],
          ),
          if (logs.isEmpty)
            AppCard(
              elevated: false,
              color: meal.color.withValues(alpha: 0.06),
              onTap: onAdd,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                context.tr(
                  uz: 'Hali hech narsa yo‘q — qo‘shish uchun bosing',
                  ru: 'Пока пусто — нажмите, чтобы добавить',
                  en: 'Nothing yet — tap to add',
                ),
                style: text.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < logs.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 72),
                    _LogTile(
                      key: ValueKey(logs[i].id),
                      log: logs[i],
                      color: meal.color,
                      onServings: (v) => onServings(logs[i], v),
                      onRemove: () => onRemove(logs[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    super.key,
    required this.log,
    required this.color,
    required this.onServings,
    required this.onRemove,
  });

  final FoodLog log;
  final Color color;
  final ValueChanged<double> onServings;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final pending = isPendingLog(log);
    final portion = log.food.portion;
    final removeLabel = context.tr(
      uz: 'O‘chirish',
      ru: 'Удалить',
      en: 'Remove',
    );

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          EmojiBox(emoji: log.food.emoji ?? '🍽️', color: color, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.trMap(log.food.name),
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    '${log.kcal.round()} ${kcalUnit(context)}',
                    if (portion != null)
                      '${formatServings(log.servings)} × $portion',
                  ].join(' · '),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (pending)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: log.servings <= servingsStep
                  ? removeLabel
                  : context.tr(
                      uz: 'Porsiyani kamaytirish',
                      ru: 'Уменьшить порцию',
                      en: 'Smaller portion',
                    ),
              onPressed: log.servings <= servingsStep
                  ? onRemove
                  : () => onServings(log.servings - servingsStep),
              icon: Icon(
                log.servings <= servingsStep
                    ? Icons.delete_outline_rounded
                    : Icons.remove_rounded,
                size: 20,
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                formatServings(log.servings),
                textAlign: TextAlign.center,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.tr(
                uz: 'Porsiyani oshirish',
                ru: 'Увеличить порцию',
                en: 'Bigger portion',
              ),
              onPressed: log.servings >= maxServings
                  ? null
                  : () => onServings(log.servings + servingsStep),
              icon: const Icon(Icons.add_rounded, size: 20),
            ),
          ],
        ],
      ),
    );

    if (pending) return row;
    return Dismissible(
      key: ValueKey('dismiss-${log.id}'),
      direction: DismissDirection.endToStart,
      // The notifier drops the row synchronously; returning false keeps
      // Dismissible from asserting if the row was already gone.
      confirmDismiss: (_) async {
        onRemove();
        return false;
      },
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
          semanticLabel: removeLabel,
        ),
      ),
      child: row,
    );
  }
}
