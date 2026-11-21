import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/emoji_box.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_ring.dart';
import '../application/plan_generator.dart';
import '../application/voice_coach.dart';
import '../application/voice_providers.dart';
import '../application/workout_run.dart';
import '../application/workouts_providers.dart';
import '../data/models.dart';
import '../data/voice.dart';
import 'labels.dart';

/// Path of the player for plan day [day] (`PlanDay.day`).
String workoutPlayerPath(int day) => '${AppRoutes.workouts}/play/$day';

/// Full-screen workout of one plan day: sets with a timer or reps, rest
/// with a countdown that can be skipped, final screen with ~kcal and XP;
/// the session goes to `workout_sessions`.
class WorkoutPlayerScreen extends ConsumerWidget {
  const WorkoutPlayerScreen({super.key, required this.day});

  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(latestPlanProvider);
    final catalog = ref.watch(exercisesByIdProvider);
    final title = context.tr(uz: 'Mashg‘ulot', ru: 'Тренировка', en: 'Workout');

    Widget scaffold(Widget body) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );

    return AsyncValueView(
      value: plan,
      onRetry: () => ref.invalidate(latestPlanProvider),
      loading: () => scaffold(const LoadingView()),
      data: (p) {
        PlanDay? planDay;
        for (final d in p?.days ?? const <PlanDay>[]) {
          if (d.day == day) planDay = d;
        }
        if (p == null || planDay == null) {
          return scaffold(
            EmptyState(
              emoji: '🗓️',
              title: context.tr(
                uz: 'Bu kun rejada yo‘q',
                ru: 'Этого дня нет в плане',
                en: 'This day is not in the plan',
              ),
            ),
          );
        }
        final d = planDay;
        return AsyncValueView(
          value: catalog,
          onRetry: () => ref.invalidate(exercisesProvider),
          loading: () => scaffold(const LoadingView()),
          data: (byId) => _Player(
            day: d,
            steps: buildSteps(
              d,
              byId,
              restSeconds: PlanParams.fromJson(p.params).restSeconds,
            ),
          ),
        );
      },
    );
  }
}

class _Player extends ConsumerStatefulWidget {
  const _Player({required this.day, required this.steps});

  final PlanDay day;
  final List<RunStep> steps;

  @override
  ConsumerState<_Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<_Player> {
  late WorkoutRun _run = WorkoutRun.start(widget.steps);
  Timer? _timer;

  /// Saving of the finished session (`null` until done).
  Future<WorkoutSession?>? _saving;

  late final Speaker _speaker;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _set(_run.tick()),
    );
    // The voices are known a moment later: greet once they are.
    ref.listenManual<VoiceLang?>(activeVoiceProvider, (prev, voice) {
      if (prev == null && voice != null && _run.phase == RunPhase.ready) {
        _speaker.say(startCue(_run, voice), voice);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speaker.stop();
    super.dispose();
  }

  void _set(WorkoutRun next) {
    if (!mounted) return;
    final before = _run;
    setState(() => _run = next);
    final voice = ref.read(activeVoiceProvider);
    if (voice != null) {
      final say = cues(before, next, voice);
      if (say.isNotEmpty) _speaker.say(say.join('. '), voice);
    }
    if (next.phase != before.phase || next.index != before.index) {
      HapticFeedback.mediumImpact();
    }
    if (next.phase == RunPhase.done && before.phase != RunPhase.done) {
      _timer?.cancel();
      _saving = _save();
    }
  }

  Future<WorkoutSession?> _save() async {
    if (_run.setsDone == 0) return null;
    return ref
        .read(sessionActionsProvider)
        .save(planDay: widget.day.day, kcal: _run.kcal);
  }

  void _retrySave() => setState(() => _saving = _save());

  Future<bool> _confirmExit() async {
    final wasPaused = _run.paused;
    if (!wasPaused) _set(_run.togglePause());
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr(
            uz: 'Mashg‘ulotni to‘xtatasizmi?',
            ru: 'Остановить тренировку?',
            en: 'Stop the workout?',
          ),
        ),
        content: Text(
          context.tr(
            uz: '«Tugatish» bajarilgan setlarni saqlaydi.',
            ru: '«Завершить» сохранит выполненные подходы.',
            en: '“Finish” saves the sets you have done.',
          ),
        ),
        actions: [
          TextButton(
            key: const Key('player-exit-discard'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.tr(
                uz: 'Saqlamasdan chiqish',
                ru: 'Выйти без сохранения',
                en: 'Leave without saving',
              ),
            ),
          ),
          TextButton(
            key: const Key('player-exit-finish'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.tr(uz: 'Tugatish', ru: 'Завершить', en: 'Finish'),
            ),
          ),
          FilledButton(
            key: const Key('player-exit-continue'),
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.tr(uz: 'Davom etish', ru: 'Продолжить', en: 'Continue'),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (exit == true) return true;
    if (exit == false) {
      _set(_run.finish());
    } else if (!wasPaused && _run.paused) {
      _set(_run.togglePause());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final done = _run.phase == RunPhase.done;
    final d = widget.day;
    return PopScope(
      canPop: done,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${context.tr(uz: '${d.day}-kun', ru: 'День ${d.day}', en: 'Day ${d.day}')}'
            '${d.weekday == null ? '' : ' · ${weekdayName(context, d.weekday!)}'}',
          ),
          leading: IconButton(
            key: const Key('player-close'),
            tooltip: context.tr(uz: 'Yopish', ru: 'Закрыть', en: 'Close'),
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            Consumer(
              builder: (context, ref, _) {
                final on = ref.watch(activeVoiceProvider) != null;
                return IconButton(
                  key: const Key('player-voice'),
                  tooltip: context.tr(
                    uz: 'Ovozli murabbiy',
                    ru: 'Голосовой тренер',
                    en: 'Voice coach',
                  ),
                  icon: Icon(
                    on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  ),
                  onPressed: () => showVoiceSheet(context),
                );
              },
            ),
          ],
          bottom: done
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    key: const Key('player-progress'),
                    value: _run.progress,
                    minHeight: 4,
                  ),
                ),
        ),
        body: SafeArea(
          child: done
              ? _Finish(
                  run: _run,
                  saving: _saving,
                  onRetry: _retrySave,
                  onClose: () => Navigator.of(context).pop(),
                )
              : _Running(
                  run: _run,
                  onDone: () => _set(_run.completeSet()),
                  onSkip: () => _set(_run.skip()),
                  onSkipSet: () => _set(_run.skipSet()),
                  onAddRest: () => _set(_run.addRest()),
                  onPause: () => _set(_run.togglePause()),
                ),
        ),
      ),
    );
  }
}

String _clock(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class _Running extends StatelessWidget {
  const _Running({
    required this.run,
    required this.onDone,
    required this.onSkip,
    required this.onSkipSet,
    required this.onAddRest,
    required this.onPause,
  });

  final WorkoutRun run;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onSkipSet;
  final VoidCallback onAddRest;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final step = run.step!;
    final e = step.exercise;
    final phase = run.phase;
    final ready = phase == RunPhase.ready;
    final rest = phase == RunPhase.rest;
    final timed = run.isTimedWork;
    final shown = rest ? run.nextWork : step;
    final exerciseNo = _exerciseNumber(run, shown ?? step);
    final exerciseCount = {for (final s in run.steps) s.item}.length;

    final (label, color) = switch (phase) {
      RunPhase.ready => (
        context.tr(uz: 'Tayyorlaning', ru: 'Приготовьтесь', en: 'Get ready'),
        AppColors.amber,
      ),
      RunPhase.rest => (
        context.tr(uz: 'Dam olish', ru: 'Отдых', en: 'Rest'),
        AppColors.sky,
      ),
      _ => (
        context.tr(
          uz: '${step.set}-set / ${step.item.sets}',
          ru: 'Подход ${step.set} из ${step.item.sets}',
          en: 'Set ${step.set} of ${step.item.sets}',
        ),
        AppColors.violet,
      ),
    };

    final total = switch (phase) {
      RunPhase.ready => readySeconds,
      RunPhase.rest =>
        step.seconds! < run.remaining ? run.remaining : step.seconds!,
      _ => step.workSeconds ?? 1,
    };

    final big = ready || rest || timed
        ? ProgressRing(
            key: const Key('player-ring'),
            value: run.remaining / total,
            size: 220,
            strokeWidth: 14,
            color: color,
            duration: const Duration(milliseconds: 300),
            child: Text(
              _clock(run.remaining),
              key: const Key('player-timer'),
              style: text.displayMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          )
        : Column(
            children: [
              Text(
                '× ${step.reps}',
                key: const Key('player-reps'),
                style: text.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                context.tr(uz: 'marta', ru: 'повторений', en: 'reps'),
                style: text.titleMedium,
              ),
            ],
          );

    final next = run.nextWork;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Text(
              context.tr(
                uz: 'Mashq $exerciseNo / $exerciseCount',
                ru: 'Упражнение $exerciseNo из $exerciseCount',
                en: 'Exercise $exerciseNo of $exerciseCount',
              ),
              style: text.bodySmall,
            ),
            const Spacer(),
            Icon(Icons.timer_outlined, size: 16, color: text.bodySmall?.color),
            const SizedBox(width: 4),
            Text(
              _clock(run.elapsed),
              key: const Key('player-elapsed'),
              style: text.bodySmall,
            ),
            const SizedBox(width: 12),
            Text(
              '~${run.kcal.round()} ${kcalUnit(context)}',
              key: const Key('player-kcal'),
              style: text.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            EmojiBox(
              emoji: muscleEmoji((shown ?? step).exercise.muscle),
              color: color,
              size: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    key: const Key('player-phase'),
                    style: text.labelLarge?.copyWith(color: color),
                  ),
                  Text(
                    context.trMap((shown ?? step).exercise.name),
                    key: const Key('player-exercise'),
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!rest && e.hint.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(context.trMap(e.hint), style: text.bodyMedium),
        ],
        const SizedBox(height: 28),
        Center(child: big),
        const SizedBox(height: 28),
        if (ready || rest)
          Row(
            children: [
              if (rest) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('player-add-rest'),
                    onPressed: onAddRest,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      context.tr(
                        uz: '+$restExtraSeconds s',
                        ru: '+$restExtraSeconds с',
                        en: '+$restExtraSeconds s',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  key: const Key('player-skip'),
                  onPressed: onSkip,
                  icon: Icons.skip_next_rounded,
                  label: ready
                      ? context.tr(uz: 'Boshlash', ru: 'Начать', en: 'Start')
                      : context.tr(
                          uz: 'O‘tkazib yuborish',
                          ru: 'Пропустить',
                          en: 'Skip',
                        ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  key: const Key('player-skip-set'),
                  onPressed: onSkipSet,
                  icon: const Icon(Icons.redo_rounded),
                  // One line on a small phone — shrink, never break a word.
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.tr(uz: 'O‘tkazish', ru: 'Пропуск', en: 'Skip'),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: PrimaryButton(
                  key: const Key('player-done'),
                  onPressed: onDone,
                  icon: Icons.check_rounded,
                  label: context.tr(uz: 'Bajarildi', ru: 'Готово', en: 'Done'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            key: const Key('player-pause'),
            onPressed: onPause,
            icon: Icon(
              run.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            ),
            label: Text(
              run.paused
                  ? context.tr(
                      uz: 'Davom etish',
                      ru: 'Продолжить',
                      en: 'Resume',
                    )
                  : context.tr(uz: 'Pauza', ru: 'Пауза', en: 'Pause'),
            ),
          ),
        ),
        if (next != null && !rest) ...[
          const SizedBox(height: 8),
          AppCard(
            elevated: false,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  context.tr(uz: 'Keyingi:', ru: 'Далее:', en: 'Next:'),
                  style: text.bodySmall,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.trMap(next.exercise.name),
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(doseText(context, next.item), style: text.bodySmall),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 1-based number of the exercise of [step] in the day.
  static int _exerciseNumber(WorkoutRun run, RunStep step) {
    final items = <PlanItem>[];
    for (final s in run.steps) {
      if (!items.contains(s.item)) items.add(s.item);
    }
    return items.indexOf(step.item) + 1;
  }
}

class _Finish extends ConsumerWidget {
  const _Finish({
    required this.run,
    required this.saving,
    required this.onRetry,
    required this.onClose,
  });

  final WorkoutRun run;
  final Future<WorkoutSession?>? saving;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final all = run.setsDone == run.totalSets;
    final nothing = run.setsDone == 0;
    final streak = ref.watch(streakProvider).value;

    Widget stat(String value, String label, Color color, Key key) => Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              key: key,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: text.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Center(
          child: Text(
            nothing ? '🙂' : (all ? '🎉' : '👍'),
            style: const TextStyle(fontSize: 64),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          nothing
              ? context.tr(
                  uz: 'Bu safar set bajarilmadi',
                  ru: 'В этот раз подходов нет',
                  en: 'No sets this time',
                )
              : all
              ? context.tr(
                  uz: 'Mashg‘ulot tugadi!',
                  ru: 'Тренировка завершена!',
                  en: 'Workout complete!',
                )
              : context.tr(
                  uz: 'Yaxshi ish!',
                  ru: 'Хорошая работа!',
                  en: 'Good job!',
                ),
          key: const Key('player-finish-title'),
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(
            uz: '${run.setsDone} / ${run.totalSets} set bajarildi',
            ru: 'Выполнено подходов: ${run.setsDone} из ${run.totalSets}',
            en: '${run.setsDone} of ${run.totalSets} sets done',
          ),
          key: const Key('player-finish-sets'),
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            stat(
              '${run.minutes}',
              minUnit(context),
              AppColors.sky,
              const Key('player-finish-minutes'),
            ),
            const SizedBox(width: 10),
            stat(
              '~${run.kcal.round()}',
              kcalUnit(context),
              AppColors.coral,
              const Key('player-finish-kcal'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppCard(
                gradient: nothing ? null : AppColors.saffronGradient,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                child: Column(
                  children: [
                    // Counts up to the earned XP.
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: run.xp),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Text(
                        '+$v',
                        key: const Key('player-finish-xp'),
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: nothing ? AppColors.saffron : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'XP',
                      style: text.bodySmall?.copyWith(
                        color: nothing ? null : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!nothing)
          FutureBuilder<WorkoutSession?>(
            future: saving,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const LoadingView(compact: true);
              }
              if (snap.hasError) {
                return ErrorView(
                  error: snap.error!,
                  onRetry: onRetry,
                  compact: true,
                );
              }
              return AppCard(
                key: const Key('player-finish-saved'),
                color: AppColors.amber.withValues(alpha: 0.12),
                elevated: false,
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        streak == null || streak == 0
                            ? context.tr(
                                uz: 'Saqlandi',
                                ru: 'Сохранено',
                                en: 'Saved',
                              )
                            : context.tr(
                                uz: 'Ketma-ket $streak kun!',
                                ru: '$streak дн. подряд!',
                                en: '$streak days in a row!',
                              ),
                        key: const Key('player-finish-streak'),
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        PrimaryButton(
          key: const Key('player-finish-close'),
          onPressed: onClose,
          icon: Icons.check_rounded,
          label: context.tr(uz: 'Yopish', ru: 'Закрыть', en: 'Close'),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr(
            uz:
                'Kaloriya taxminiy. Og‘riq yoki bosh aylanishi bo‘lsa, '
                'to‘xtating. Shifokor maslahatini almashtirmaydi.',
            ru:
                'Калории приблизительные. При боли или головокружении '
                'остановитесь. Не заменяет консультацию врача.',
            en:
                'Calories are estimates. Stop if you feel pain or dizziness. '
                'Does not replace a doctor’s advice.',
          ),
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
    if (nothing) return list;
    return Stack(
      children: [
        list,
        const Align(alignment: Alignment.topCenter, child: _Celebration()),
      ],
    );
  }
}

/// A burst of confetti in the brand colors when the finish screen opens.
class _Celebration extends StatefulWidget {
  const _Celebration();

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> {
  final _c = ConfettiController(duration: const Duration(milliseconds: 1500));

  /// The particles are gone by then; the widget leaves the tree so nothing
  /// keeps animating.
  static const _lifetime = Duration(seconds: 4);
  Timer? _end;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _c.play();
    _end = Timer(_lifetime, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _end?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // «Reduce motion» in the system settings — no confetti.
    if (!_visible || MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ConfettiWidget(
        key: const Key('player-confetti'),
        confettiController: _c,
        blastDirectionality: BlastDirectionality.explosive,
        numberOfParticles: 24,
        emissionFrequency: 0.06,
        gravity: 0.25,
        colors: const [
          AppColors.primary,
          AppColors.secondary,
          AppColors.saffron,
          AppColors.coral,
          AppColors.violet,
          AppColors.good,
        ],
      ),
    );
  }
}

/// Voice coach setting: auto / a language / off; languages the phone
/// lacks are marked, «auto» says what it speaks now.
Future<void> showVoiceSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => const SafeArea(child: _VoiceSheet()),
);

class _VoiceSheet extends ConsumerWidget {
  const _VoiceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final choice = ref.watch(voiceChoiceProvider);
    final langs = ref.watch(voiceLangsProvider);
    final active = ref.watch(activeVoiceProvider);
    final available = langs.value ?? const <VoiceLang>{};

    String langName(VoiceLang l) => switch (l) {
      VoiceLang.uz => 'O‘zbekcha',
      VoiceLang.ru => 'Русский',
      VoiceLang.en => 'English',
    };

    String? missing(VoiceLang l) => langs.hasValue && !available.contains(l)
        ? context.tr(
            uz: 'Telefonda bu ovoz yo‘q',
            ru: 'На телефоне нет этого голоса',
            en: 'This phone has no such voice',
          )
        : null;

    final autoNow = active == null
        ? context.tr(
            uz: 'Mos ovoz topilmadi — jim',
            ru: 'Подходящий голос не найден — без звука',
            en: 'No suitable voice — silent',
          )
        : context.tr(
            uz: 'Hozir: ${langName(active)}',
            ru: 'Сейчас: ${langName(active)}',
            en: 'Now: ${langName(active)}',
          );

    Widget option(VoiceChoice c, String title, String? subtitle) =>
        RadioListTile<VoiceChoice>(
          key: Key('player-voice-${c.name}'),
          value: c,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
        );

    return RadioGroup<VoiceChoice>(
      groupValue: choice,
      onChanged: (c) {
        if (c != null) ref.read(voiceChoiceProvider.notifier).set(c);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                context.tr(
                  uz: 'Ovozli murabbiy',
                  ru: 'Голосовой тренер',
                  en: 'Voice coach',
                ),
                style: text.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.tr(
                  uz:
                      'Hisoblaydi («bir, ikki, uch…»), dam olishni va keyingi '
                      'mashqni aytadi. O‘zbek ovozi bo‘lmasa — rus tilida.',
                  ru:
                      'Считает («раз, два, три…»), объявляет отдых и '
                      'следующее упражнение. Нет узбекского голоса — по-русски.',
                  en:
                      'Counts («one, two, three…»), announces rest and the '
                      'next exercise. No Uzbek voice — Russian.',
                ),
                style: text.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            option(
              VoiceChoice.auto,
              context.tr(uz: 'Avtomatik', ru: 'Автоматически', en: 'Auto'),
              autoNow,
            ),
            for (final l in VoiceLang.values)
              option(
                VoiceChoice.values.byName(l.name),
                langName(l),
                missing(l),
              ),
            option(
              VoiceChoice.off,
              context.tr(uz: 'O‘chirilgan', ru: 'Выключен', en: 'Off'),
              null,
            ),
          ],
        ),
      ),
    );
  }
}
