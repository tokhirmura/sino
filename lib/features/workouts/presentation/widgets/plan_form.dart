import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../application/plan_generator.dart';
import '../../data/models.dart';
import '../labels.dart';

/// Generator inputs: sport × goal × level × days per week.
class PlanForm extends StatefulWidget {
  const PlanForm({
    super.key,
    required this.onSubmit,
    this.initial = const PlanParams(),
  });

  final PlanParams initial;

  /// Builds and saves the plan; the button shows progress until it ends.
  final Future<void> Function(PlanParams params) onSubmit;

  @override
  State<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<PlanForm> {
  late PlanParams _p = widget.initial;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_p);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label(context.tr(uz: 'Sport turi', ru: 'Вид спорта', en: 'Sport')),
        _Chips(
          children: [
            for (final t in WorkoutType.values)
              ChoiceChip(
                key: Key('workouts-type-${t.name}'),
                label: Text('${t.emoji} ${t.label(context)}'),
                selected: _p.type == t,
                onSelected: (_) => setState(() => _p = _p.copyWith(type: t)),
              ),
          ],
        ),
        _Label(context.tr(uz: 'Maqsad', ru: 'Цель', en: 'Goal')),
        _Chips(
          children: [
            for (final g in WorkoutGoal.values)
              ChoiceChip(
                key: Key('workouts-goal-${g.name}'),
                label: Text('${g.emoji} ${g.label(context)}'),
                selected: _p.goal == g,
                onSelected: (_) => setState(() => _p = _p.copyWith(goal: g)),
              ),
          ],
        ),
        _Label(context.tr(uz: 'Daraja', ru: 'Уровень', en: 'Level')),
        _Chips(
          children: [
            for (final l in WorkoutLevel.values)
              ChoiceChip(
                key: Key('workouts-level-${l.name}'),
                label: Text(l.label(context)),
                selected: _p.level == l,
                onSelected: (_) => setState(() => _p = _p.copyWith(level: l)),
              ),
          ],
        ),
        _Label(
          context.tr(
            uz: 'Haftasiga necha kun',
            ru: 'Дней в неделю',
            en: 'Days per week',
          ),
        ),
        _Chips(
          children: [
            for (var d = minPlanDays; d <= maxPlanDays; d++)
              ChoiceChip(
                key: Key('workouts-days-$d'),
                label: Text('$d'),
                selected: _p.daysPerWeek == d,
                onSelected: (_) =>
                    setState(() => _p = _p.copyWith(daysPerWeek: d)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('workouts-generate'),
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(
            context.tr(
              uz: 'Reja tuzish',
              ru: 'Составить план',
              en: 'Build plan',
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}
