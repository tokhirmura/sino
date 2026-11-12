import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/home_card.dart';
import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/section_title.dart';
import '../application/health_index.dart';
import 'widgets/health_index_card.dart';
import 'widgets/services_grid.dart';

/// First word of the full name: «Aziz Karimov» → «Aziz».
String firstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.first;
}

/// «payshanba, 12-noyabr» → «Payshanba, 12-noyabr» (uz/ru dates are lowercase).
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Home: greeting, today's health index, quick services grid, then the
/// cards every feature contributes (`homeCardsProvider`, sorted by order).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(homeCardsProvider);
    final user = ref.watch(currentUserProvider);
    final index = ref.watch(healthIndexProvider);
    final name = firstName(user.value?.fullName ?? '');
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      title: context.tr(
        uz: 'Salom${name.isEmpty ? '' : ', $name'}',
        ru: 'Привет${name.isEmpty ? '' : ', $name'}',
        en: 'Hi${name.isEmpty ? '' : ', $name'}',
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(currentUserProvider.future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Text(
              capitalize(
                MaterialLocalizations.of(context)
                    .formatFullDate(DateTime.now()),
              ),
              style: text.bodyMedium?.copyWith(color: text.bodySmall?.color),
            ),
            const SizedBox(height: 12),
            index.when(
              skipLoadingOnReload: true,
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(currentUserProvider),
              ),
              data: (i) => i == null
                  ? const SizedBox.shrink()
                  : HealthIndexCard(index: i),
            ),
            SectionTitle(
              context.tr(uz: 'Xizmatlar', ru: 'Сервисы', en: 'Services'),
            ),
            const ServicesGrid(),
            if (cards.isNotEmpty) ...[
              SectionTitle(
                context.tr(uz: 'Siz uchun', ru: 'Для вас', en: 'For you'),
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
    );
  }
}
