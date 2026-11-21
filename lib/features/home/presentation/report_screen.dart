import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/home_today.dart';
import '../application/sino_index.dart';
import '../application/weekly_report.dart';
import 'widgets/sino_index_card.dart' show levelColor, levelLabel;
import 'widgets/week_strip_card.dart' show weekdayShort;

/// `/report` — the week in one card: index by day (fl_chart), best day,
/// water, workouts, medicines. «Ulashish» shares the card as a picture.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _shot = ScreenshotController();
  var _sharing = false;

  Future<void> _share(WeeklyReport r) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.tr(
      uz: 'Ulashib bo‘lmadi. Qayta urinib ko‘ring.',
      ru: 'Не удалось поделиться. Попробуйте ещё раз.',
      en: 'Couldn’t share. Please try again.',
    );
    final text = context.tr(
      uz: 'Mening Sino haftam: o‘rtacha indeks ${r.average} / 100 💚',
      ru: 'Моя неделя в Sino: средний индекс ${r.average} / 100 💚',
      en: 'My week in Sino: average index ${r.average} / 100 💚',
    );
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(2.0, 3.0);
    try {
      final png = await _shot.capture(pixelRatio: pixelRatio);
      if (png == null) throw StateError('no image');
      await ref.read(reportSharerProvider)(png, text);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(weeklyReportProvider);
    return AppScaffold(
      title: context.tr(
        uz: 'Haftalik hisobot',
        ru: 'Отчёт за неделю',
        en: 'Weekly report',
      ),
      subtitle: report.value == null
          ? null
          : _range(context, report.value!.from, report.value!.to),
      body: AsyncValueView(
        value: report,
        onRetry: () => ref.invalidate(sinoHistoryProvider),
        loading: () => const SkeletonLoader(count: 3, kind: SkeletonKind.card),
        data: (r) => r.isEmpty
            ? EmptyState(
                emoji: '📊',
                title: context.tr(
                  uz: 'Bu hafta hali ma’lumot yo‘q',
                  ru: 'За эту неделю пока нет данных',
                  en: 'No data for this week yet',
                ),
                message: context.tr(
                  uz:
                      'Suv, ovqat, dori yoki uyquni qayd eting — hisobot '
                      'o‘zi tuziladi.',
                  ru:
                      'Отмечайте воду, еду, лекарства или сон — отчёт '
                      'соберётся сам.',
                  en:
                      'Log water, food, medicines or sleep — the report '
                      'builds itself.',
                ),
                actionLabel: context.tr(
                  uz: 'Bosh sahifaga',
                  ru: 'На главную',
                  en: 'Go home',
                ),
                onAction: () => context.go(AppRoutes.home),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, 24),
                children: [
                  Screenshot(
                    controller: _shot,
                    child: ReportCard(report: r),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    key: const ValueKey('report-share'),
                    label: context.tr(
                      uz: 'Ulashish',
                      ru: 'Поделиться',
                      en: 'Share',
                    ),
                    icon: Icons.ios_share_rounded,
                    loading: _sharing,
                    onPressed: () => _share(r),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.tr(
                      uz:
                          'Karta rasm sifatida yuboriladi — oila yoki '
                          'shifokoringizga.',
                      ru: 'Карточка отправится картинкой — семье или врачу.',
                      en:
                          'The card is sent as a picture — to family or '
                          'your doctor.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}

/// «15 – 21 noyabr».
String _range(BuildContext context, DateTime from, DateTime to) {
  final locale = Localizations.localeOf(context).toString();
  final sameMonth = from.month == to.month;
  final a = DateFormat(sameMonth ? 'd' : 'd MMMM', locale).format(from);
  final b = DateFormat('d MMMM', locale).format(to);
  return '$a – $b';
}

/// The card that is shared as a picture: opaque background, everything
/// needed to read it without the app.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final r = report;
    final lang = context.lang;
    final level = SinoLevel.of(r.average!);
    final brand = AppColors.brand(theme.brightness);

    return Material(
      key: const ValueKey('report-card'),
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: brand gradient, average index.
          Container(
            decoration: BoxDecoration(gradient: brand),
            child: Stack(
              children: [
                const Positioned.fill(child: GirihPattern(opacity: 0.08)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                uz: 'Sino · haftalik hisobot',
                                ru: 'Sino · отчёт за неделю',
                                en: 'Sino · weekly report',
                              ),
                              style: text.labelLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _range(context, r.from, r.to),
                              style: text.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _DeltaPill(delta: r.delta),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${r.average}',
                            key: const ValueKey('report-average'),
                            style: text.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          Text(
                            context.tr(
                              uz: 'o‘rtacha indeks',
                              ru: 'средний индекс',
                              en: 'average index',
                            ),
                            style: text.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            levelLabel(context, level),
                            style: text.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 4),
            child: SizedBox(
              height: 170,
              child: _IndexChart(days: r.days, lang: lang),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _Stats(report: r),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Text(
              context.tr(
                uz: 'Shifokor maslahatini almashtirmaydi',
                ru: 'Не заменяет консультацию врача',
                en: 'Does not replace medical advice',
              ),
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final int? delta;

  @override
  Widget build(BuildContext context) {
    final d = delta;
    final label = d == null
        ? context.tr(
            uz: 'Birinchi hafta 🌱',
            ru: 'Первая неделя 🌱',
            en: 'First week 🌱',
          )
        : d == 0
        ? context.tr(
            uz: 'O‘tgan haftadek',
            ru: 'Как на прошлой неделе',
            en: 'Same as last week',
          )
        : context.tr(
            uz: '${d > 0 ? '▲ +' : '▼ '}$d o‘tgan haftaga nisbatan',
            ru: '${d > 0 ? '▲ +' : '▼ '}$d к прошлой неделе',
            en: '${d > 0 ? '▲ +' : '▼ '}$d vs last week',
          );
    return Container(
      key: const ValueKey('report-delta'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Index by day: bars in the level color, dashed line at 60 (streak).
class _IndexChart extends StatelessWidget {
  const _IndexChart({required this.days, required this.lang});

  final List<SinoDay> days;
  final AppLang lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final grid = theme.dividerColor.withValues(alpha: 0.4);
    return Semantics(
      label: [
        for (final d in days)
          '${weekdayShort(lang, d.date.weekday)} ${d.index?.score ?? '–'}',
      ].join(', '),
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 100,
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: grid, strokeWidth: 1),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: sinoStreakThreshold.toDouble(),
                color: AppColors.saffron,
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 25,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('${v.round()}', style: text.labelSmall),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= days.length || v != i) {
                    return const SizedBox.shrink();
                  }
                  final score = days[i].index?.score;
                  return SideTitleWidget(
                    meta: meta,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          score == null ? '–' : '$score',
                          style: text.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          weekdayShort(lang, days[i].date.weekday),
                          style: text.labelSmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (days[i].index?.score ?? 0).toDouble(),
                    width: 18,
                    color: days[i].index == null
                        ? theme.colorScheme.outlineVariant
                        : levelColor(SinoLevel.of(days[i].index!.score)),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 100,
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final lang = context.lang;
    final best = r.best!;
    final bestDay = DateFormat(
      'EEEE',
      Localizations.localeOf(context).toString(),
    ).format(best.date);
    final share = r.dosesShare;

    Widget tile(StatTile t) => Expanded(child: t);
    return Column(
      children: [
        Row(
          children: [
            tile(
              StatTile(
                key: const ValueKey('report-best'),
                emoji: '🏆',
                value: '${best.index!.score}',
                label: context.tr(
                  uz: 'Eng yaxshi kun',
                  ru: 'Лучший день',
                  en: 'Best day',
                ),
                caption: capitalizeFirst(bestDay),
                color: AppColors.saffron,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            tile(
              StatTile(
                key: const ValueKey('report-water'),
                emoji: '💧',
                value: '${r.glasses}',
                unit: switch (lang) {
                  AppLang.uz => 'stakan',
                  AppLang.ru => 'стак.',
                  AppLang.en => 'glasses',
                },
                label: context.tr(uz: 'Suv', ru: 'Вода', en: 'Water'),
                caption: context.tr(
                  uz: '8 stakan: ${r.waterGoalDays} kun',
                  ru: '8 стаканов: ${r.waterGoalDays} дн.',
                  en: '8 glasses: ${r.waterGoalDays} days',
                ),
                color: AppColors.sky,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            tile(
              StatTile(
                key: const ValueKey('report-workouts'),
                emoji: '🏋️',
                value: '${r.workouts}',
                label: context.tr(
                  uz: 'Mashg‘ulot',
                  ru: 'Тренировки',
                  en: 'Workouts',
                ),
                caption: r.stepsPerDay == null
                    ? null
                    : context.tr(
                        uz: 'Kuniga ~${groupThousands(r.stepsPerDay!)} qadam',
                        ru: '~${groupThousands(r.stepsPerDay!)} шагов в день',
                        en: '~${groupThousands(r.stepsPerDay!)} steps a day',
                      ),
                color: AppColors.coral,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            tile(
              StatTile(
                key: const ValueKey('report-meds'),
                emoji: '💊',
                value: share == null ? '–' : '${(share * 100).round()}',
                unit: share == null ? null : '%',
                label: context.tr(
                  uz: 'Dorilar vaqtida',
                  ru: 'Лекарства вовремя',
                  en: 'Medicines on time',
                ),
                caption: share == null
                    ? context.tr(
                        uz: 'Eslatmalar yo‘q',
                        ru: 'Нет напоминаний',
                        en: 'No reminders',
                      )
                    : '${r.dosesTaken} / ${r.dosesDue}',
                color: AppColors.violet,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// «shanba» → «Shanba».
String capitalizeFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
