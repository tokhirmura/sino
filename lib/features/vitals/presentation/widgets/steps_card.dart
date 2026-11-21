import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../application/steps.dart';
import '../../application/steps_providers.dart';

/// Today's steps on the vitals screen: ring to [stepsGoal], ~km and ~kcal,
/// and what to do when the sensor is silent or missing (S2-3).
class StepsCard extends ConsumerWidget {
  const StepsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(stepsProvider);
    final text = Theme.of(context).textTheme;
    final steps = v.steps;
    final warn = switch (v.status) {
      StepsStatus.silent || StepsStatus.denied || StepsStatus.blocked => true,
      _ => false,
    };
    return _StepsLifecycle(
      askOnce: true,
      child: AppCard(
        key: const Key('vitals-steps'),
        animate: false,
        child: Row(
          children: [
            _Ring(steps: steps, size: 116),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      uz: 'Bugungi qadamlar',
                      ru: 'Шаги сегодня',
                      en: 'Steps today',
                    ),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (steps != null && steps > 0) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      context.tr(
                        uz:
                            '~${stepsKm(steps).toStringAsFixed(1)} km · '
                            '~${stepsKcal(steps)} kkal',
                        ru:
                            '~${stepsKm(steps).toStringAsFixed(1)} км · '
                            '~${stepsKcal(steps)} ккал',
                        en:
                            '~${stepsKm(steps).toStringAsFixed(1)} km · '
                            '~${stepsKcal(steps)} kcal',
                      ),
                      style: text.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _statusText(context, v),
                    key: const Key('vitals-steps-status'),
                    style: text.bodyMedium?.copyWith(
                      color: warn
                          ? AppColors.readable(
                              AppColors.saffron,
                              Theme.of(context).brightness,
                            )
                          : null,
                    ),
                  ),
                  if (v.status == StepsStatus.denied) ...[
                    const SizedBox(height: AppSpacing.xs),
                    FilledButton.tonalIcon(
                      key: const Key('vitals-steps-allow'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => ref.read(stepsProvider.notifier).allow(),
                      icon: const Icon(Icons.directions_walk_rounded, size: 18),
                      label: Text(
                        context.tr(
                          uz: 'Ruxsat berish',
                          ru: 'Разрешить',
                          en: 'Allow',
                        ),
                      ),
                    ),
                  ],
                  if (v.status == StepsStatus.blocked ||
                      v.status == StepsStatus.silent) ...[
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton.icon(
                      key: const Key('vitals-steps-settings'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () =>
                          ref.read(stepsProvider.notifier).openSettings(),
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: Text(
                        context.tr(
                          uz: 'Sozlamalarni ochish',
                          ru: 'Открыть настройки',
                          en: 'Open settings',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact home card: ring + «N / 8000»; tap → `/vitals`.
class StepsHomeCard extends ConsumerWidget {
  const StepsHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(stepsProvider);
    final text = Theme.of(context).textTheme;
    final steps = v.steps;
    return _StepsLifecycle(
      child: AppCard(
        key: const Key('steps-home-card'),
        onTap: () => context.push(AppRoutes.vitals),
        child: Row(
          children: [
            _Ring(steps: steps, size: 64, compact: true),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(uz: 'Qadamlar', ru: 'Шаги', en: 'Steps'),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${steps ?? '—'} / $stepsGoal',
                    key: const Key('steps-home-count'),
                    style: text.bodyMedium,
                  ),
                  Text(
                    _statusText(context, v),
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

String _statusText(BuildContext context, StepsView v) {
  final steps = v.steps ?? 0;
  return switch (v.status) {
    StepsStatus.unavailable => context.tr(
      uz: 'Bu qurilmada qadam sensori yo‘q (emulyatorda ishlamaydi).',
      ru: 'На этом устройстве нет датчика шагов (в эмуляторе не работает).',
      en: 'This device has no step sensor (it doesn’t work in an emulator).',
    ),
    StepsStatus.silent => context.tr(
      uz:
          'Qadamlar hali kelmadi — biroz yuring. Hisoblanmasa, sozlamalarda '
          '«Jismoniy faollik» ruxsatini tekshiring.',
      ru:
          'Шагов пока нет — пройдитесь немного. Если не считает, проверьте '
          'в настройках разрешение «Физическая активность».',
      en:
          'No steps yet — take a short walk. If nothing counts, check the '
          '«Physical activity» permission in Settings.',
    ),
    StepsStatus.denied => context.tr(
      uz:
          'Qadamlarni sanash uchun «Jismoniy faollik» ruxsati kerak. '
          'Ma’lumot faqat telefoningizda hisoblanadi.',
      ru:
          'Чтобы считать шаги, нужно разрешение «Физическая активность». '
          'Шаги считаются только на вашем телефоне.',
      en:
          'Counting steps needs the «Physical activity» permission. '
          'Steps are counted on your phone only.',
    ),
    StepsStatus.blocked => context.tr(
      uz:
          'Ruxsat berilmagan. Sozlamalar → Ruxsatlar → «Jismoniy faollik» '
          '(iPhone’da «Harakat va fitnes») → Ruxsat berish.',
      ru:
          'Доступ запрещён. Настройки → Разрешения → «Физическая активность» '
          '(на iPhone — «Движение и фитнес») → Разрешить.',
      en:
          'Access denied. Settings → Permissions → «Physical activity» '
          '(on iPhone — «Motion & Fitness») → Allow.',
    ),
    StepsStatus.starting => context.tr(
      uz: 'Qadam sensori ulanmoqda…',
      ru: 'Подключаем датчик шагов…',
      en: 'Connecting the step sensor…',
    ),
    StepsStatus.counting when steps >= stepsGoal => context.tr(
      uz: 'Maqsad bajarildi! 🎉',
      ru: 'Цель выполнена! 🎉',
      en: 'Goal reached! 🎉',
    ),
    StepsStatus.counting => context.tr(
      uz: 'Maqsadgacha ${stepsGoal - steps} qadam',
      ru: 'До цели ${stepsGoal - steps} шагов',
      en: '${stepsGoal - steps} steps to the goal',
    ),
  };
}

/// Ring to the goal; the number counts up smoothly.
class _Ring extends StatelessWidget {
  const _Ring({required this.steps, required this.size, this.compact = false});

  final int? steps;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = steps;
    final colors = (s ?? 0) >= stepsGoal
        ? const [AppColors.saffron, AppColors.coral]
        : const [AppColors.primary, AppColors.secondary];
    if (s == null) {
      return AnimatedProgressRing(
        value: 0,
        size: size,
        strokeWidth: compact ? 7 : 12,
        colors: colors,
        label: compact ? '👣' : '—',
        caption: compact ? null : '/ $stepsGoal',
      );
    }
    return TweenAnimationBuilder<double>(
      key: const Key('vitals-steps-count'),
      tween: Tween(end: s.toDouble()),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      builder: (_, x, _) => AnimatedProgressRing(
        value: s / stepsGoal,
        size: size,
        strokeWidth: compact ? 7 : 12,
        colors: colors,
        label: compact ? '👣' : '${x.round()}',
        caption: compact ? null : '/ $stepsGoal',
        semanticsLabel: '$s / $stepsGoal',
      ),
    );
  }
}

/// Saves the total when the app leaves the foreground and listens again
/// on return (the user may have just allowed the permission).
class _StepsLifecycle extends ConsumerStatefulWidget {
  const _StepsLifecycle({required this.child, this.askOnce = false});

  final Widget child;

  /// The vitals screen card asks for the permission once by itself (the
  /// home card only shows the state).
  final bool askOnce;

  @override
  ConsumerState<_StepsLifecycle> createState() => _StepsLifecycleState();
}

class _StepsLifecycleState extends ConsumerState<_StepsLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.askOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(stepsProvider.notifier).askOnce();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final n = ref.read(stepsProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      n.restart();
    } else if (state == AppLifecycleState.paused) {
      n.flush();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
