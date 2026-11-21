import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contracts/home_card.dart';
import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/data/achievements.dart';
import '../application/achievements_check.dart';
import '../application/goal_order.dart';
import '../application/home_today.dart';
import '../application/sino_index.dart';
import 'widgets/achievement_celebration.dart';
import 'widgets/home_header.dart';
import 'widgets/quote_card.dart';
import 'widgets/services_grid.dart';
import 'widgets/sino_index_card.dart';
import 'widgets/week_strip_card.dart';

/// First word of the full name: «Aziz Karimov» → «Aziz».
String firstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.first;
}

/// «payshanba, 12-noyabr» → «Payshanba, 12-noyabr» (uz/ru dates are lowercase).
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Home «Bugun»: gradient greeting with today's live summary → Sino index
/// ring (tap → breakdown) → streak and the 7-day strip → proverb of the
/// day → quick services → every feature's home card (`homeCardsProvider`).
///
/// Data is reloaded when the user comes back to this tab (after logging
/// water, food, medicines elsewhere) and on pull-to-refresh. Each reload
/// checks the badges; new ones are saved and celebrated with confetti.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  GoRouter? _router;
  String? _lastPath;
  final _celebrated = <Achievement>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onRoute);
      _router = router?..routerDelegate.addListener(_onRoute);
      _lastPath = _path;
    }
  }

  String? get _path => _router?.routerDelegate.currentConfiguration.uri.path;

  void _onRoute() {
    final path = _path;
    if (path == AppRoutes.home && _lastPath != AppRoutes.home) _reload();
    _lastPath = path;
  }

  void _reload() => ref.invalidate(sinoHistoryProvider);

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onNewAchievements(
    AsyncValue<List<Achievement>>? _,
    AsyncValue<List<Achievement>> next,
  ) {
    if (next.isLoading || !next.hasValue) return;
    final fresh = next.requireValue.where(_celebrated.add).toList();
    if (fresh.isEmpty || !ref.read(achievementCelebrationProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showAchievementCelebration(context, fresh);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(newAchievementsProvider, _onNewAchievements);
    final goal = ref.watch(currentUserProvider).value?.goal;
    final cards = orderCardsForGoal(ref.watch(homeCardsProvider), goal);
    final lang = ref.watch(appLangProvider);
    final today = ref.watch(sinoTodayProvider);
    final week = ref.watch(sinoWeekProvider);
    final streak = ref.watch(sinoStreakProvider);
    final quote = ref.watch(quoteOfTheDayProvider);

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: RefreshIndicator(
          edgeOffset: 120,
          onRefresh: () async {
            ref.invalidate(currentUserProvider);
            _reload();
            await ref.read(sinoHistoryProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const HomeHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AsyncValueView(
                      value: today,
                      compact: true,
                      onRetry: _reload,
                      loading: () => const SkeletonLoader(
                        count: 1,
                        kind: SkeletonKind.card,
                      ),
                      data: (t) => SinoIndexCard(today: t),
                    ),
                    const SizedBox(height: AppSpacing.cardGap),
                    if (week.value case final w?)
                      WeekStripCard(
                        week: w,
                        streak: streak.value ?? 0,
                        lang: lang,
                      ),
                    if (quote.value case final q?) ...[
                      const SizedBox(height: AppSpacing.cardGap),
                      QuoteCard(quote: q, lang: lang),
                    ],
                    SectionTitle(
                      context.tr(
                        uz: 'Xizmatlar',
                        ru: 'Сервисы',
                        en: 'Services',
                      ),
                    ),
                    const ServicesGrid(),
                    if (cards.isNotEmpty) ...[
                      SectionTitle(
                        context.tr(
                          uz: 'Siz uchun',
                          ru: 'Для вас',
                          en: 'For you',
                        ),
                      ),
                      if (goal != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Pill(
                              '${goal.emoji} ${goal.title(lang)}',
                              key: const ValueKey('home-goal'),
                              wrap: true,
                            ),
                          ),
                        ),
                      for (final card in cards)
                        Padding(
                          key: ValueKey('home-card-${card.id}'),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Builder(builder: card.builder),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
