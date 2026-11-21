import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/achievements.dart';
import '../../../../core/l10n/app_lang.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';

/// «Yangi yutuq!» dialog with confetti for freshly unlocked badges.
/// «Barcha yutuqlar» opens the badges screen in the profile.
Future<void> showAchievementCelebration(
  BuildContext context,
  List<Achievement> items,
) {
  final router = GoRouter.maybeOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: AppMotion.medium,
    pageBuilder: (context, _, _) => AchievementCelebration(
      items: items,
      onAll: router == null
          ? null
          : () {
              Navigator.of(context).pop();
              router.push(AppRoutes.achievements);
            },
    ),
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(
          begin: 0.85,
          end: 1.0,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

class AchievementCelebration extends StatefulWidget {
  const AchievementCelebration({super.key, required this.items, this.onAll});

  final List<Achievement> items;
  final VoidCallback? onAll;

  @override
  State<AchievementCelebration> createState() => _AchievementCelebrationState();
}

class _AchievementCelebrationState extends State<AchievementCelebration> {
  final _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1400),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final lang = context.lang;
    final items = widget.items;
    final single = items.length == 1;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Material(
              key: const ValueKey('achievement-celebration'),
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.sheet),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        single
                            ? context.tr(
                                uz: 'Yangi yutuq! 🎉',
                                ru: 'Новое достижение! 🎉',
                                en: 'New badge! 🎉',
                              )
                            : context.tr(
                                uz: '${items.length} ta yangi yutuq! 🎉',
                                ru: 'Новых достижений: ${items.length} 🎉',
                                en: '${items.length} new badges! 🎉',
                              ),
                        textAlign: TextAlign.center,
                        style: text.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final a in items)
                            AchievementBadge(
                              key: ValueKey('new-badge-${a.code}'),
                              emoji: a.emoji,
                              title: a.title(lang),
                              size: single ? 96 : 64,
                            ),
                        ],
                      ),
                      if (single) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          items.first.hint(lang),
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: context.tr(
                          uz: 'Zo‘r!',
                          ru: 'Отлично!',
                          en: 'Great!',
                        ),
                        icon: Icons.celebration_rounded,
                        gradient: AppColors.saffronGradient,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      if (widget.onAll != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        TextButton(
                          onPressed: widget.onAll,
                          child: Text(
                            context.tr(
                              uz: 'Barcha yutuqlar',
                              ru: 'Все достижения',
                              en: 'All badges',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: math.pi / 2,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.06,
            numberOfParticles: 18,
            maxBlastForce: 28,
            minBlastForce: 10,
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
        ),
      ],
    );
  }
}
