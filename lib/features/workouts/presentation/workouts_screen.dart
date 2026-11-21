import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/storage/prefs.dart';
import '../application/air_quality.dart';
import '../application/plan_generator.dart';
import '../application/workouts_providers.dart';
import '../data/models.dart';
import 'labels.dart';
import 'workout_player_screen.dart';
import 'widgets/plan_day_card.dart';
import 'widgets/plan_form.dart';

/// «Sport» tab: the weekly plan, or the generator when there is none.
class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(latestPlanProvider);
    final catalog = ref.watch(exercisesByIdProvider);
    // Read on every build: the weather feature may have just saved it.
    final aqi = readTodayAqi(
      ref.watch(sharedPreferencesProvider),
      DateTime.now(),
    );

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

    final p = plan.value;
    final streak = ref.watch(streakProvider).value;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestPlanProvider);
          ref.invalidate(exercisesProvider);
          ref.invalidate(sessionsProvider);
          await ref
              .read(latestPlanProvider.future)
              .catchError((Object _) => null);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _Header(plan: p, streak: streak),
            Padding(
              padding: AppSpacing.screen,
              child: AsyncValueView(
                value: plan,
                onRetry: () => ref.invalidate(latestPlanProvider),
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.cardGap),
                  child: SkeletonLoader(count: 3, kind: SkeletonKind.card),
                ),
                data: (p) => p == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Intro(),
                          AppCard(
                            child: PlanForm(aqi: aqi, onSubmit: create),
                          ),
                          const _Disclaimer(),
                        ],
                      )
                    : AsyncValueView(
                        value: catalog,
                        onRetry: () => ref.invalidate(exercisesProvider),
                        loading: () => const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.cardGap),
                          child: SkeletonLoader(
                            count: 3,
                            kind: SkeletonKind.card,
                          ),
                        ),
                        data: (byId) => _PlanView(
                          plan: p,
                          catalog: byId,
                          aqi: aqi,
                          onNewPlan: () => _openGenerator(
                            context,
                            PlanParams.fromJson(p.params),
                            aqi,
                            (params) => create(params, closeSheet: true),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openGenerator(
    BuildContext context,
    PlanParams initial,
    TodayAqi? aqi,
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
            PlanForm(initial: initial, aqi: aqi, onSubmit: onSubmit),
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
    this.aqi,
  });

  final WorkoutPlan plan;
  final Map<String, Exercise> catalog;
  final VoidCallback onNewPlan;
  final TodayAqi? aqi;

  @override
  Widget build(BuildContext context) {
    final params = PlanParams.fromJson(plan.params);
    final week = weekTotals(plan.days);
    final text = Theme.of(context).textTheme;
    final a = aqi;
    final outdoorWarning = a != null && a.isBad && isOutdoor(params.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.cardGap),
        if (outdoorWarning) ...[
          AppCard(
            key: const Key('workouts-plan-air-warning'),
            elevated: false,
            color: AppColors.danger.withValues(alpha: 0.12),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('😷', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    airAlertText(context, a.aqi),
                    style: text.bodyMedium,
                  ),
                ),
                TextButton(
                  key: const Key('workouts-plan-air-home'),
                  onPressed: onNewPlan,
                  child: Text(
                    context.tr(
                      uz: 'Uyda reja',
                      ru: 'План дома',
                      en: 'Home plan',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
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
          PlanDayCard(
            day: d,
            catalog: catalog,
            onStart: () => context.push(workoutPlayerPath(d.day)),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const _Disclaimer(),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => EmptyState(
    key: const Key('workouts-intro'),
    emoji: '🏋️',
    title: context.tr(
      uz: 'Mashg‘ulot rejangizni tuzamiz',
      ru: 'Составим план тренировок',
      en: 'Let’s build your workout plan',
    ),
    message: context.tr(
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
  );
}

/// Gradient header: title and, with a plan, the week's numbers.
class _Header extends StatelessWidget {
  const _Header({required this.plan, required this.streak});

  final WorkoutPlan? plan;
  final int? streak;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final week = p == null ? null : weekTotals(p.days);
    final s = streak ?? 0;
    return GradientHeader(
      title: context.tr(uz: 'Sport', ru: 'Тренировки', en: 'Workouts'),
      subtitle: p == null
          ? context.tr(
              uz: 'Shaxsiy haftalik reja',
              ru: 'Личный план на неделю',
              en: 'Your weekly plan',
            )
          : context.tr(
              uz: 'Haftasiga ${p.days.length} kun',
              ru: '${p.days.length} дн. в неделю',
              en: '${p.days.length} days a week',
            ),
      child: week == null
          ? null
          : Row(
              children:
                  [
                        Expanded(
                          child: StatTile(
                            key: const Key('workouts-header-streak'),
                            value: '$s',
                            unit: context.tr(uz: 'kun', ru: 'дн.', en: 'days'),
                            label: context.tr(
                              uz: 'Seriya',
                              ru: 'Серия',
                              en: 'Streak',
                            ),
                            emoji: '🔥',
                            color: AppColors.saffron,
                            onDark: true,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: StatTile(
                            value: '${week.minutes}',
                            unit: minUnit(context),
                            label: context.tr(
                              uz: 'Haftada',
                              ru: 'В неделю',
                              en: 'Per week',
                            ),
                            emoji: '⏱️',
                            color: AppColors.sky,
                            onDark: true,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: StatTile(
                            value: '~${week.kcal}',
                            unit: kcalUnit(context),
                            label: context.tr(
                              uz: 'Yoqiladi',
                              ru: 'Сжечь',
                              en: 'Burn',
                            ),
                            emoji: '💪',
                            color: AppColors.coral,
                            onDark: true,
                          ),
                        ),
                      ]
                      .animate(interval: AppMotion.stagger)
                      .fadeIn(duration: AppMotion.medium)
                      .slideY(begin: 0.15, curve: AppMotion.enter),
            ),
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
