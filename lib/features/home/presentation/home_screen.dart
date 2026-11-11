import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/home_card.dart';
import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

/// Stub: greeting + all features' home cards in a column (sorted by order).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(homeCardsProvider);
    final user = ref.watch(currentUserProvider).value;
    final name = user?.fullName ?? '';
    return AppScaffold(
      title: context.tr(
        uz: 'Salom${name.isEmpty ? '' : ', $name'}',
        ru: 'Привет${name.isEmpty ? '' : ', $name'}',
        en: 'Hi${name.isEmpty ? '' : ', $name'}',
      ),
      body: cards.isEmpty
          ? EmptyState(
              title: context.tr(
                uz: 'Asosiy — tez orada',
                ru: 'Главная — скоро',
                en: 'Home — coming soon',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => KeyedSubtree(
                key: ValueKey('home-card-${cards[i].id}'),
                child: cards[i].builder(context),
              ),
            ),
    );
  }
}
