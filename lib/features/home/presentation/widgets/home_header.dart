import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/user.dart';
import '../../../../core/l10n/app_lang.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../application/home_today.dart';
import '../../application/sino_index.dart';
import '../home_screen.dart' show capitalize, firstName;

/// Gradient header: greeting by the time of day + name, date and the live
/// one-line summary of today.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(sinoClockProvider)();
    final lang = ref.watch(appLangProvider);
    final name = firstName(
      ref.watch(currentUserProvider).value?.fullName ?? '',
    );
    final today = ref.watch(sinoTodayProvider);
    final summary = today.value == null
        ? null
        : todaySummary(lang, today.value!, now) ??
              context.tr(
                uz: 'Bugun hali hech narsa qayd etilmagan — suvdan boshlang 💧',
                ru: 'Сегодня пока ничего не отмечено — начните с воды 💧',
                en: 'Nothing logged today yet — start with water 💧',
              );
    final text = Theme.of(context).textTheme;

    return GradientHeader(
      key: const ValueKey('home-header'),
      title: greeting(lang, DayPart.of(now), name),
      subtitle: capitalize(
        MaterialLocalizations.of(context).formatFullDate(now),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: summary == null
            ? const SizedBox(height: 40, key: ValueKey('summary-loading'))
            : Container(
                key: ValueKey(summary),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  summary,
                  key: const ValueKey('today-summary'),
                  style: text.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}
