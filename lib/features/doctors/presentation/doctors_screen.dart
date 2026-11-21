import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/doctors_providers.dart';
import '../data/doctors_repository.dart';
import '../data/models.dart';
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
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            GradientHeader(
              leading: canPop ? const BackButton(color: Colors.white) : null,
              title: context.tr(uz: 'Shifokorlar', ru: 'Врачи', en: 'Doctors'),
              subtitle: context.tr(
                uz: 'Qabulga yoki onlayn maslahatga yoziling',
                ru: 'Запись на приём или онлайн-консультацию',
                en: 'Book a visit or an online consultation',
              ),
              trailing: IconButton(
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
              child: Column(
                children: [
                  _searchField(theme),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          onDark: true,
                          value: '${catalog.value?.length ?? '—'}',
                          label: context.tr(
                            uz: 'Shifokorlar',
                            ru: 'Врачи',
                            en: 'Doctors',
                          ),
                          icon: Icons.medical_services_rounded,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: StatTile(
                          onDark: true,
                          value: '${upcoming.length}',
                          label: context.tr(
                            uz: 'Yozuvlarim',
                            ru: 'Мои записи',
                            en: 'My visits',
                          ),
                          icon: Icons.event_available_rounded,
                          onTap: () => context.push(DoctorsPaths.appointments),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AsyncValueView(
                value: catalog,
                compact: true,
                onRetry: () => ref.invalidate(doctorsCatalogProvider),
                loading: () => const SkeletonLoader(count: 5),
                data: (all) => _catalog(context, all, upcoming.length),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(ThemeData theme) => TextField(
    controller: _search,
    textInputAction: TextInputAction.search,
    style: TextStyle(color: theme.colorScheme.onSurface),
    decoration: InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surface,
      hintText: context.tr(
        uz: 'Ism, mutaxassislik yoki klinika',
        ru: 'Имя, специальность или клиника',
        en: 'Name, specialty or clinic',
      ),
      prefixIcon: Icon(
        Icons.search_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: context.tr(uz: 'Tozalash', ru: 'Очистить', en: 'Clear'),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () => setState(() {
                _search.clear();
                _query = '';
              }),
              icon: const Icon(Icons.close_rounded),
            ),
    ),
    onChanged: (v) => setState(() => _query = v),
  );

  Widget _catalog(BuildContext context, List<Doctor> all, int upcoming) {
    final list = filterDoctors(
      all,
      specialty: _specialty,
      query: _query,
      onlineOnly: _onlineOnly,
    );
    final specialties = ref.watch(specialtiesProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (upcoming > 0) ...[
          _NextAppointmentBanner(count: upcoming),
          const SizedBox(height: 12),
        ],
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
                label: Text(context.tr(uz: 'Hammasi', ru: 'Все', en: 'All')),
                selected: _specialty == null,
                onSelected: (_) => setState(() => _specialty = null),
              ),
              for (final s in specialties) ...[
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(specialtyLabel(context, s)),
                  selected: _specialty == s,
                  onSelected: (v) => setState(() => _specialty = v ? s : null),
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
            actionLabel: context.tr(
              uz: 'Filtrni tozalash',
              ru: 'Сбросить фильтр',
              en: 'Clear filters',
            ),
            actionIcon: Icons.filter_alt_off_rounded,
            onAction: () => setState(() {
              _search.clear();
              _query = '';
              _specialty = null;
              _onlineOnly = false;
            }),
          )
        else
          for (final (i, d) in list.indexed)
            DoctorTile(
              key: ValueKey('doc-${d.id}-$_query-$_specialty-$_onlineOnly'),
              index: i,
              doctor: d,
              onTap: () => context.push(DoctorsPaths.doctor(d.id)),
            ),
        const SizedBox(height: 8),
        const DoctorsDisclaimer(),
      ],
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
          Icon(
            Icons.event_available_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
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
                    appointmentWhen(
                      context,
                      next.startsAt,
                      ref.watch(doctorsClockProvider)(),
                    ),
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
