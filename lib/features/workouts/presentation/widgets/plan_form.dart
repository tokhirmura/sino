import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/air_quality.dart';
import '../../application/plan_generator.dart';
import '../../data/models.dart';
import '../labels.dart';

/// Generator inputs: sport × goal × level × days per week.
class PlanForm extends StatefulWidget {
  const PlanForm({
    super.key,
    required this.onSubmit,
    this.initial = const PlanParams(),
    this.aqi,
  });

  final PlanParams initial;

  /// Today's air quality; above [badAqiLimit] an outdoor sport is swapped
  /// for «at home» and a banner explains why (P1-6).
  final TodayAqi? aqi;

  /// Builds and saves the plan; the button shows progress until it ends.
  final Future<void> Function(PlanParams params) onSubmit;

  @override
  State<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<PlanForm> {
  late PlanParams _p = _initial();
  bool _busy = false;

  /// The generator itself chose «at home» because of the air.
  bool _switchedHome = false;

  bool get _badAir => widget.aqi?.isBad ?? false;

  PlanParams _initial() {
    final p = widget.initial;
    // No plan yet (defaults) or an outdoor sport: pick «at home» for today.
    if (_badAir && (isOutdoor(p.type) || p == const PlanParams())) {
      _switchedHome = true;
      return p.copyWith(type: WorkoutType.home);
    }
    return p;
  }

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
        if (_badAir) ...[
          const SizedBox(height: 8),
          _AirBanner(
            aqi: widget.aqi!,
            outdoor: isOutdoor(_p.type),
            switchedHome: _switchedHome && _p.type == WorkoutType.home,
            onHome: () =>
                setState(() => _p = _p.copyWith(type: WorkoutType.home)),
          ),
        ],
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

class _AirBanner extends StatelessWidget {
  const _AirBanner({
    required this.aqi,
    required this.outdoor,
    required this.switchedHome,
    required this.onHome,
  });

  final TodayAqi aqi;

  /// An outdoor sport is selected right now.
  final bool outdoor;
  final bool switchedHome;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final place = aqi.place.isEmpty ? '' : ', ${context.trMap(aqi.place)}';
    final color = outdoor ? AppColors.danger : const Color(0xFFF97316);
    return AppCard(
      key: const Key('workouts-air-banner'),
      elevated: false,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('😷', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  outdoor
                      ? context.tr(
                          uz:
                              'Bugun havo sifati yomon (AQI ${aqi.aqi}$place). '
                              'Ochiq havoda yugurish tavsiya etilmaydi — uyda '
                              'mashq qiling.',
                          ru:
                              'Сегодня плохой воздух (AQI ${aqi.aqi}$place). '
                              'Бег на улице не советуем — тренируйтесь дома.',
                          en:
                              'Poor air today (AQI ${aqi.aqi}$place). Running '
                              'outside is not advised — train at home.',
                        )
                      : switchedHome
                      ? context.tr(
                          uz:
                              'Bugun havo sifati yomon (AQI ${aqi.aqi}$place) — '
                              'generator ochiq havo o‘rniga uyda mashg‘ulotni '
                              'tanladi.',
                          ru:
                              'Сегодня плохой воздух (AQI ${aqi.aqi}$place) — '
                              'генератор выбрал тренировку дома вместо улицы.',
                          en:
                              'Poor air today (AQI ${aqi.aqi}$place) — the '
                              'generator picked a home workout instead of '
                              'outdoors.',
                        )
                      : context.tr(
                          uz:
                              'Bugun havo sifati yomon (AQI ${aqi.aqi}$place) — '
                              'mashg‘ulotni uyda yoki yopiq zalda qiling.',
                          ru:
                              'Сегодня плохой воздух (AQI ${aqi.aqi}$place) — '
                              'тренируйтесь дома или в закрытом зале.',
                          en:
                              'Poor air today (AQI ${aqi.aqi}$place) — train '
                              'at home or indoors.',
                        ),
                  key: const Key('workouts-air-text'),
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
          if (outdoor) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                key: const Key('workouts-air-home'),
                onPressed: onHome,
                icon: const Icon(Icons.home_rounded),
                label: Text(context.tr(uz: 'Uyda', ru: 'Дома', en: 'At home')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
