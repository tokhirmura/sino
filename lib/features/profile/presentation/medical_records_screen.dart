import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/emoji_box.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/pill.dart';
import '../data/medical_repository.dart';
import 'labels.dart';

/// Filter value for «only me».
const _me = '';

/// Electronic medical record: feed of `medical_records`, newest first,
/// with a davlat / xususiy label and a filter by person.
class MedicalRecordsScreen extends ConsumerStatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  ConsumerState<MedicalRecordsScreen> createState() =>
      _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends ConsumerState<MedicalRecordsScreen> {
  /// null — everyone, [_me] — the user, otherwise a family member id.
  String? _who;

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(medicalRecordsProvider);
    final family = ref.watch(familyMembersProvider).value ?? const [];
    final names = {for (final m in family) m.id: m.name};

    return AppScaffold(
      title: context.tr(
        uz: 'Tibbiy karta',
        ru: 'Медкарта',
        en: 'Medical record',
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(medicalRecordsProvider),
        ),
        data: (all) {
          final shown = [
            for (final r in all)
              if (_who == null || (r.memberId ?? _me) == _who) r,
          ];
          return RefreshIndicator(
            onRefresh: () => ref.refresh(medicalRecordsProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _Filter(
                  family: family,
                  selected: _who,
                  onSelected: (v) => setState(() => _who = v),
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  EmptyState(
                    emoji: '📂',
                    title: context.tr(
                      uz: 'Hozircha yozuvlar yo‘q',
                      ru: 'Пока нет записей',
                      en: 'No records yet',
                    ),
                    message: context.tr(
                      uz:
                          'Poliklinika va klinikalardagi ko‘rik, tahlil va '
                          'retseptlar shu yerda ko‘rinadi.',
                      ru:
                          'Здесь появятся приёмы, анализы и рецепты из '
                          'поликлиник и клиник.',
                      en:
                          'Visits, lab tests and prescriptions from clinics '
                          'will appear here.',
                    ),
                  )
                else
                  for (final r in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RecordCard(
                        record: r,
                        memberName: r.memberId == null
                            ? null
                            : names[r.memberId],
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.family,
    required this.selected,
    required this.onSelected,
  });

  final List<FamilyMember> family;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String? value) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onSelected(value),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(context.tr(uz: 'Hammasi', ru: 'Все', en: 'All'), null),
          chip(context.tr(uz: 'Men', ru: 'Я', en: 'Me'), _me),
          for (final m in family) chip(m.name, m.id),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, this.memberName});

  final MedicalRecord record;
  final String? memberName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = record;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmojiBox(emoji: recordEmoji(r.kind), color: sourceColor(r.source)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: text.titleSmall),
                if (r.institution != null) ...[
                  const SizedBox(height: 2),
                  Text(r.institution!, style: text.bodySmall),
                ],
                if (r.notes != null) ...[
                  const SizedBox(height: 6),
                  Text(r.notes!, style: text.bodyMedium),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pill(
                      sourceLabel(context, r.source),
                      color: sourceColor(r.source),
                      icon: r.source == RecordSource.davlat
                          ? Icons.account_balance_outlined
                          : Icons.local_hospital_outlined,
                    ),
                    Pill(recordKindLabel(context, r.kind)),
                    if (memberName != null)
                      Pill(memberName!, icon: Icons.family_restroom),
                    Text(shortDate(context, r.date), style: text.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
