import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/section_title.dart';
import '../application/dev_mode.dart';
import 'widgets/dev_tools.dart';

/// Stub: user + family from core providers, language switch, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final family = ref.watch(familyMembersProvider);
    final lang = ref.watch(appLangProvider);
    return AppScaffold(
      title: context.tr(uz: 'Profil', ru: 'Профиль', en: 'Profile'),
      body: ListView(
        children: [
          Text(
            context.tr(
              uz: 'Profil — tez orada',
              ru: 'Профиль — скоро',
              en: 'Profile — coming soon',
            ),
          ),
          const SizedBox(height: 12),
          user.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(currentUserProvider),
            ),
            data: (u) => ShortcutCard(
              emoji: '👤',
              title: u == null ? '—' : '${u.fullName}, ${u.age ?? '—'}',
              subtitle: u?.bloodType,
            ),
          ),
          SectionTitle(context.tr(uz: 'Oila', ru: 'Семья', en: 'Family')),
          family.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(familyMembersProvider),
            ),
            data: (list) => Column(
              children: [
                for (final m in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ShortcutCard(
                      emoji: '🧑',
                      title: '${m.name}, ${m.age ?? '—'}',
                      subtitle: m.relation,
                    ),
                  ),
              ],
            ),
          ),
          SectionTitle(context.tr(uz: 'Til', ru: 'Язык', en: 'Language')),
          SegmentedButton<AppLang>(
            segments: [
              for (final l in AppLang.values)
                ButtonSegment(value: l, label: Text(l.label)),
            ],
            selected: {lang},
            onSelectionChanged: (s) =>
                ref.read(appLangProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => signOut(ref),
            icon: const Icon(Icons.logout),
            label: Text(context.tr(uz: 'Chiqish', ru: 'Выйти', en: 'Sign out')),
          ),
          if (ref.watch(devModeProvider)) ...[
            const SizedBox(height: 24),
            const DevToolsCard(),
          ],
          const SizedBox(height: 16),
          const VersionTapper(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
