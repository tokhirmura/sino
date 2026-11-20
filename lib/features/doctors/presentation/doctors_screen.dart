import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_title.dart';
import '../application/doctors_providers.dart';
import '../data/doctors_repository.dart';
import 'doctors_paths.dart';
import 'labels.dart';
import 'widgets.dart';

/// `/doctors`: catalog with search, specialty and «online» filters.
class DoctorsScreen extends ConsumerStatefulWidget {
  const DoctorsScreen({super.key});

  @override
  ConsumerState<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends ConsumerState<DoctorsScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _specialty;
  bool _onlineOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(doctorsCatalogProvider);
    final upcoming = ref.watch(upcomingAppointmentsProvider).value ?? const [];
    return AppScaffold(
      title: context.tr(uz: 'Shifokorlar', ru: 'Врачи', en: 'Doctors'),
      padding: EdgeInsets.zero,
      actions: [
        IconButton(
          tooltip: context.tr(
            uz: 'Mening yozuvlarim',
            ru: 'Мои записи',
            en: 'My appointments',
          ),
          onPressed: () => context.push(DoctorsPaths.appointments),
          icon: Badge(
            isLabelVisible: upcoming.isNotEmpty,
            label: Text('${upcoming.length}'),
            child: const Icon(Icons.event_note_rounded),
          ),
        ),
      ],
      body: AsyncValueView(
        value: catalog,
        onRetry: () => ref.invalidate(doctorsCatalogProvider),
        loading: () => const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: SkeletonList(count: 5),
        ),
        data: (all) {
          final list = filterDoctors(
            all,
            specialty: _specialty,
            query: _query,
            onlineOnly: _onlineOnly,
          );
          final specialties = ref.watch(specialtiesProvider).value ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.tr(
                    uz: 'Ism, mutaxassislik yoki klinika',
                    ru: 'Имя, специальность или клиника',
                    en: 'Name, specialty or clinic',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.tr(
                            uz: 'Tozalash',
                            ru: 'Очистить',
                            en: 'Clear',
                          ),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 12),
                _NextAppointmentBanner(count: upcoming.length),
              ],
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.videocam_rounded, size: 18),
                      label: Text(
                        context.tr(uz: 'Onlayn', ru: 'Онлайн', en: 'Online'),
                      ),
                      selected: _onlineOnly,
                      onSelected: (v) => setState(() => _onlineOnly = v),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(
                        context.tr(uz: 'Hammasi', ru: 'Все', en: 'All'),
                      ),
                      selected: _specialty == null,
                      onSelected: (_) => setState(() => _specialty = null),
                    ),
                    for (final s in specialties) ...[
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(specialtyLabel(context, s)),
                        selected: _specialty == s,
                        onSelected: (v) =>
                            setState(() => _specialty = v ? s : null),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionTitle(
                context.tr(
                  uz: 'Shifokorlar: ${list.length}',
                  ru: 'Врачей: ${list.length}',
                  en: 'Doctors: ${list.length}',
                ),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                EmptyState(
                  emoji: '🔍',
                  title: context.tr(
                    uz: 'Shifokor topilmadi',
                    ru: 'Врачи не найдены',
                    en: 'No doctors found',
                  ),
                  message: context.tr(
                    uz: 'Filtrni o‘zgartirib ko‘ring.',
                    ru: 'Попробуйте изменить фильтр.',
                    en: 'Try another filter.',
                  ),
                )
              else
                for (final d in list)
                  DoctorTile(
                    doctor: d,
                    onTap: () => context.push(DoctorsPaths.doctor(d.id)),
                  ),
              const SizedBox(height: 8),
              const DoctorsDisclaimer(),
            ],
          );
        },
      ),
    );
  }
}

class _NextAppointmentBanner extends ConsumerWidget {
  const _NextAppointmentBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final next = ref.watch(upcomingAppointmentsProvider).value?.firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final d =
        next.doctor ?? ref.watch(doctorsByIdProvider).value?[next.doctorId];
    return AppCard(
      onTap: () => context.push(DoctorsPaths.appointments),
      color: AppColors.primary.withValues(alpha: 0.10),
      elevated: false,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    uz: 'Yaqin qabul',
                    ru: 'Ближайший приём',
                    en: 'Next appointment',
                  ),
                  style: text.labelMedium,
                ),
                Text(
                  [
                    appointmentWhen(context, next.startsAt, DateTime.now()),
                    if (d != null) d.name,
                  ].join(' · '),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
