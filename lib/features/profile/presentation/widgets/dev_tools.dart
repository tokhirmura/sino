import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/user.dart';
import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/dev_mode.dart';
import '../../data/medical_repository.dart';
import '../../data/sample_data_repository.dart';

/// «Sino · v1.0.0» line. 7 taps toggle developer mode.
class VersionTapper extends ConsumerStatefulWidget {
  const VersionTapper({super.key});

  static const version = '1.0.0';

  @override
  ConsumerState<VersionTapper> createState() => _VersionTapperState();
}

class _VersionTapperState extends ConsumerState<VersionTapper> {
  int _taps = 0;

  Future<void> _onTap() async {
    _taps++;
    if (_taps < DevModeNotifier.tapsToUnlock) return;
    _taps = 0;
    await ref.read(devModeProvider.notifier).toggle();
    if (!mounted) return;
    final on = ref.read(devModeProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            on
                ? context.tr(
                    uz: 'Dasturchi rejimi yoqildi',
                    ru: 'Режим разработчика включён',
                    en: 'Developer mode on',
                  )
                : context.tr(
                    uz: 'Dasturchi rejimi o‘chirildi',
                    ru: 'Режим разработчика выключен',
                    en: 'Developer mode off',
                  ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Sino · v${VersionTapper.version}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// Demo tools, visible only in developer mode.
class DevToolsCard extends ConsumerStatefulWidget {
  const DevToolsCard({super.key});

  @override
  ConsumerState<DevToolsCard> createState() => _DevToolsCardState();
}

class _DevToolsCardState extends ConsumerState<DevToolsCard> {
  bool _loading = false;

  Future<void> _seed() async {
    setState(() => _loading = true);
    String message;
    try {
      final r = await ref.read(sampleDataRepositoryProvider).seed();
      ref
        ..invalidate(familyMembersProvider)
        ..invalidate(medicalRecordsProvider)
        ..invalidate(labResultsProvider);
      if (!mounted) return;
      message = r.skipped
          ? context.tr(
              uz: 'Ma’lumotlar allaqachon bor — hech narsa qo‘shilmadi.',
              ru: 'Данные уже есть — ничего не добавлено.',
              en: 'Data already exists — nothing was added.',
            )
          : context.tr(
              uz:
                  'Yuklandi: oila — ${r.familyMembers}, tibbiy karta — '
                  '${r.medicalRecords}, tahlillar — ${r.labResults}.',
              ru:
                  'Загружено: семья — ${r.familyMembers}, медкарта — '
                  '${r.medicalRecords}, анализы — ${r.labResults}.',
              en:
                  'Loaded: family — ${r.familyMembers}, medical record — '
                  '${r.medicalRecords}, lab results — ${r.labResults}.',
            );
    } catch (e) {
      if (!mounted) return;
      message = context.tr(
        uz: 'Yuklab bo‘lmadi: $e',
        ru: 'Не удалось загрузить: $e',
        en: 'Could not load: $e',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: AppColors.amber.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.developer_mode, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                context.tr(
                  uz: 'Dasturchi rejimi',
                  ru: 'Режим разработчика',
                  en: 'Developer mode',
                ),
                style: text.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              uz:
                  'Hisobga namuna oila, tibbiy karta va tahlillarni qo‘shadi '
                  '(faqat bo‘sh hisobga).',
              ru:
                  'Добавляет в аккаунт демо-семью, медкарту и анализы '
                  '(только в пустой аккаунт).',
              en:
                  'Adds a sample family, medical record and lab results to '
                  'the account (empty accounts only).',
            ),
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _seed,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: const Text('Namuna ma’lumotlarni yuklash'),
          ),
        ],
      ),
    );
  }
}
