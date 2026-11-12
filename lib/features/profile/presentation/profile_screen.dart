import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_mode.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/emoji_box.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/section_title.dart';
import '../application/dev_mode.dart';
import '../data/medical_repository.dart';
import 'labels.dart';
import 'profile_paths.dart';
import 'widgets/dev_tools.dart';

/// Profile tab: the user, medical record shortcuts, family, settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return AppScaffold(
      title: context.tr(uz: 'Profil', ru: 'Профиль', en: 'Profile'),
      body: RefreshIndicator(
        onRefresh: () {
          ref
            ..invalidate(familyMembersProvider)
            ..invalidate(medicalRecordsProvider)
            ..invalidate(labResultsProvider);
          return ref.refresh(currentUserProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            user.when(
              skipLoadingOnReload: true,
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(currentUserProvider),
              ),
              data: (u) =>
                  u == null ? const SizedBox.shrink() : _UserCard(user: u),
            ),
            SectionTitle(
              context.tr(
                uz: 'Tibbiy karta',
                ru: 'Медкарта',
                en: 'Medical record',
              ),
            ),
            const _MedicalShortcuts(),
            SectionTitle(
              context.tr(uz: 'Oila', ru: 'Семья', en: 'Family'),
              trailing: TextButton.icon(
                onPressed: () => context.push(ProfilePaths.familyNew),
                icon: const Icon(Icons.add),
                label: Text(
                  context.tr(uz: 'Qo‘shish', ru: 'Добавить', en: 'Add'),
                ),
              ),
            ),
            const _FamilyList(),
            SectionTitle(
              context.tr(uz: 'Sozlamalar', ru: 'Настройки', en: 'Settings'),
            ),
            const _Settings(),
            if (ref.watch(devModeProvider)) ...[
              const SizedBox(height: 24),
              const DevToolsCard(),
            ],
            const SizedBox(height: 16),
            const VersionTapper(),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final facts = [
      if (user.age != null)
        context.tr(
          uz: '${user.age} yosh',
          ru: '${user.age} лет',
          en: '${user.age} y.o.',
        ),
      if (user.heightCm != null)
        '${formatNum(user.heightCm!)} ${context.tr(uz: 'sm', ru: 'см', en: 'cm')}',
      if (user.weightKg != null)
        '${formatNum(user.weightKg!)} ${context.tr(uz: 'kg', ru: 'кг', en: 'kg')}',
    ];
    return AppCard(
      onTap: () => context.push(ProfilePaths.edit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EmojiBox(emoji: '👤', size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (facts.isNotEmpty)
                      Text(facts.join(' · '), style: text.bodyMedium),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                semanticLabel: context.tr(
                  uz: 'Tahrirlash',
                  ru: 'Изменить',
                  en: 'Edit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                user.bloodType ??
                    context.tr(
                      uz: 'Qon guruhi: —',
                      ru: 'Группа крови: —',
                      en: 'Blood type: —',
                    ),
                color: AppColors.danger,
                icon: Icons.bloodtype_outlined,
              ),
              if (user.allergies.isEmpty)
                Pill(
                  context.tr(
                    uz: 'Allergiya yo‘q',
                    ru: 'Аллергий нет',
                    en: 'No allergies',
                  ),
                  color: AppColors.good,
                )
              else
                for (final a in user.allergies)
                  Pill(a, color: AppColors.amber, icon: Icons.warning_amber),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicalShortcuts extends ConsumerWidget {
  const _MedicalShortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(medicalRecordsProvider).value;
    final labs = ref.watch(labResultsProvider).value;
    final outside = labs?.where((l) => l.status != LabStatus.normal).length;
    return Column(
      children: [
        ShortcutCard(
          emoji: '📋',
          color: AppColors.sky,
          title: context.tr(
            uz: 'Elektron tibbiy karta',
            ru: 'Электронная медкарта',
            en: 'Electronic medical record',
          ),
          subtitle: records == null
              ? null
              : context.tr(
                  uz: '${records.length} ta yozuv · davlat va xususiy',
                  ru: '${records.length} записей · гос. и частные',
                  en: '${records.length} records · state and private',
                ),
          onTap: () => context.push(ProfilePaths.records),
        ),
        const SizedBox(height: 8),
        ShortcutCard(
          emoji: '🧪',
          color: AppColors.violet,
          title: context.tr(uz: 'Tahlillar', ru: 'Анализы', en: 'Lab results'),
          subtitle: labs == null
              ? null
              : outside == 0
              ? context.tr(
                  uz: '${labs.length} ta · hammasi me’yorda',
                  ru: '${labs.length} · все в норме',
                  en: '${labs.length} · all normal',
                )
              : context.tr(
                  uz: '${labs.length} ta · $outside tasi me’yordan tashqarida',
                  ru: '${labs.length} · $outside вне нормы',
                  en: '${labs.length} · $outside outside the range',
                ),
          onTap: () => context.push(ProfilePaths.labs),
        ),
        const SizedBox(height: 8),
        ShortcutCard(
          emoji: '🔳',
          color: AppColors.primary,
          title: context.tr(
            uz: 'Shifokor uchun QR',
            ru: 'QR для врача',
            en: 'QR for the doctor',
          ),
          subtitle: context.tr(
            uz: 'Nima ko‘rinishini o‘zingiz tanlaysiz',
            ru: 'Вы выбираете, что видно',
            en: 'You choose what is visible',
          ),
          onTap: () => context.push(ProfilePaths.qr),
        ),
      ],
    );
  }
}

class _FamilyList extends ConsumerWidget {
  const _FamilyList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyMembersProvider);
    return family.when(
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(familyMembersProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return AppCard(
            onTap: () => context.push(ProfilePaths.familyNew),
            child: Text(
              context.tr(
                uz:
                    'Yaqinlaringizni qo‘shing — ularning tibbiy kartasi ham '
                    'shu yerda bo‘ladi.',
                ru: 'Добавьте близких — их медкарта тоже будет здесь.',
                en:
                    'Add your family — their medical records will be here '
                    'too.',
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShortcutCard(
                  emoji: relationEmoji(m.relation),
                  title: m.age == null ? m.name : '${m.name}, ${m.age}',
                  subtitle: [
                    relationLabel(context, m.relation),
                    ?m.bloodType,
                    if (m.allergies.isNotEmpty) '⚠️ ${m.allergies.join(', ')}',
                  ].join(' · '),
                  onTap: () => context.push(ProfilePaths.familyMember(m.id)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings();

  /// UI language now + `profiles.lang`, so it follows the account.
  Future<void> _setLang(BuildContext context, WidgetRef ref, AppLang l) async {
    await ref.read(appLangProvider.notifier).set(l);
    final profile = ref.read(currentUserProvider).value;
    if (profile == null || profile.lang == l.name) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .save(profile.copyWith(lang: l.name));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              uz: 'Til faqat shu qurilmada saqlandi.',
              ru: 'Язык сохранён только на этом устройстве.',
              en: 'Language saved on this device only.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLangProvider);
    final mode = ref.watch(themeModeProvider);
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(uz: 'Til', ru: 'Язык', en: 'Language'),
            style: text.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<AppLang>(
            showSelectedIcon: false,
            segments: [
              for (final l in AppLang.values)
                ButtonSegment(value: l, label: Text(l.label)),
            ],
            selected: {lang},
            onSelectionChanged: (s) => _setLang(context, ref, s.first),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(uz: 'Mavzu', ru: 'Тема', en: 'Theme'),
            style: text.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_outlined),
                label: Text(
                  context.tr(uz: 'Tizim', ru: 'Система', en: 'System'),
                ),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_outlined),
                label: Text(
                  context.tr(uz: 'Yorug‘', ru: 'Светлая', en: 'Light'),
                ),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_outlined),
                label: Text(
                  context.tr(uz: 'Qorong‘i', ru: 'Тёмная', en: 'Dark'),
                ),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => signOut(ref),
            icon: const Icon(Icons.logout),
            label: Text(context.tr(uz: 'Chiqish', ru: 'Выйти', en: 'Sign out')),
          ),
        ],
      ),
    );
  }
}
