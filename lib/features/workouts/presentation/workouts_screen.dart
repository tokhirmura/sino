import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/section_title.dart';
import '../application/plan_generator.dart';
import '../application/workouts_providers.dart';
import '../data/models.dart';
import 'labels.dart';
import 'widgets/plan_day_card.dart';
import 'widgets/plan_form.dart';

/// «Sport» tab: the weekly plan, or the generator when there is none.
class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(latestPlanProvider);
    final catalog = ref.watch(exercisesByIdProvider);

    Future<void> create(PlanParams params, {bool closeSheet = false}) async {
      try {
        await ref.read(planActionsProvider).create(params);
        if (!context.mounted) return;
        if (closeSheet) Navigator.of(context).pop();
        _snack(
          context,
          context.tr(
            uz: 'Yangi reja tayyor',
            ru: 'Новый план готов',
            en: 'New plan is ready',
          ),
        );
      } catch (e) {
        if (context.mounted) _snack(context, errorMessage(context, e));
      }
    }

    return AppScaffold(
      title: context.tr(uz: 'Sport', ru: 'Тренировки', en: 'Workouts'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestPlanProvider);
          ref.invalidate(exercisesProvider);
          await ref
              .read(latestPlanProvider.future)
              .catchError((Object _) => null);
        },
        child: AsyncValueView(
          value: plan,
          onRetry: () => ref.invalidate(latestPlanProvider),
          loading: () => const SkeletonList(count: 3, itemHeight: 160),
          data: (p) => p == null
              ? ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    const SizedBox(height: 8),
                    const _Intro(),
                    const SizedBox(height: 12),
                    AppCard(child: PlanForm(onSubmit: create)),
                    const _Disclaimer(),
                  ],
                )
              : AsyncValueView(
                  value: catalog,
                  onRetry: () => ref.invalidate(exercisesProvider),
                  data: (byId) => _PlanView(
                    plan: p,
                    catalog: byId,
                    onNewPlan: () => _openGenerator(
                      context,
                      PlanParams.fromJson(p.params),
                      (params) => create(params, closeSheet: true),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  static Future<void> _openGenerator(
    BuildContext context,
    PlanParams initial,
    Future<void> Function(PlanParams) onSubmit,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(uz: 'Yangi reja', ru: 'Новый план', en: 'New plan'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            PlanForm(initial: initial, onSubmit: onSubmit),
          ],
        ),
      ),
    ),
  );

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PlanView extends StatelessWidget {
  const _PlanView({
    required this.plan,
    required this.catalog,
    required this.onNewPlan,
  });

  final WorkoutPlan plan;
  final Map<String, Exercise> catalog;
  final VoidCallback onNewPlan;

  @override
  Widget build(BuildContext context) {
    final params = PlanParams.fromJson(plan.params);
    final week = weekTotals(plan.days);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr(
                  uz: 'Haftalik reja',
                  ru: 'План на неделю',
                  en: 'Weekly plan',
                ),
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Pill(
                    '${params.type.emoji} ${params.type.label(context)}',
                    color: AppColors.violet,
                  ),
                  Pill(
                    '${params.goal.emoji} ${params.goal.label(context)}',
                    color: AppColors.primary,
                  ),
                  Pill(params.level.label(context), color: AppColors.amber),
                  Pill(
                    context.tr(
                      uz: 'Haftasiga ${plan.days.length} kun',
                      ru: '${plan.days.length} дн. в неделю',
                      en: '${plan.days.length} days a week',
                    ),
                    color: AppColors.sky,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                key: const Key('workouts-week-total'),
                context.tr(
                  uz:
                      'Haftasiga ${week.minutes} ${minUnit(context)} · '
                      '~${week.kcal} ${kcalUnit(context)}',
                  ru:
                      'В неделю ${week.minutes} ${minUnit(context)} · '
                      '~${week.kcal} ${kcalUnit(context)}',
                  en:
                      '${week.minutes} ${minUnit(context)} a week · '
                      '~${week.kcal} ${kcalUnit(context)}',
                ),
                style: text.bodyMedium,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('workouts-new-plan'),
                  onPressed: onNewPlan,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(
                    context.tr(
                      uz: 'Yangi reja tuzish',
                      ru: 'Составить новый план',
                      en: 'Build a new plan',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionTitle(
          context.tr(
            uz: 'Mashg‘ulot kunlari',
            ru: 'Дни тренировок',
            en: 'Training days',
          ),
        ),
        for (final d in plan.days) ...[
          PlanDayCard(day: d, catalog: catalog),
          const SizedBox(height: 12),
        ],
        const _Disclaimer(),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            uz: 'Mashg‘ulot rejangizni tuzamiz',
            ru: 'Составим план тренировок',
            en: 'Let’s build your workout plan',
          ),
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(
            uz:
                'Sport turi, maqsad, daraja va kunlar sonini tanlang — '
                'haftalik reja daqiqa va kaloriya bilan tayyor bo‘ladi.',
            ru:
                'Выберите вид спорта, цель, уровень и число дней — план на '
                'неделю с минутами и калориями будет готов.',
            en:
                'Pick a sport, goal, level and number of days — you get a '
                'weekly plan with minutes and calories.',
          ),
          style: text.bodyMedium,
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Text(
      context.tr(
        uz:
            'Reja va kaloriya taxminiy. Surunkali kasallik yoki og‘riq '
            'bo‘lsa, avval shifokorga murojaat qiling. Shifokor maslahatini '
            'almashtirmaydi.',
        ru:
            'План и калории приблизительные. При хронических болезнях или '
            'боли сначала обратитесь к врачу. Не заменяет консультацию врача.',
        en:
            'The plan and calories are estimates. With a chronic condition '
            'or pain, see a doctor first. Does not replace a doctor’s advice.',
      ),
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    ),
  );
}
