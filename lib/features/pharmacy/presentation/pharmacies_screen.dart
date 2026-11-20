import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/emoji_box.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/pill.dart';
import '../application/pharmacy_providers.dart';
import '../data/external_launcher.dart';
import '../data/location_repository.dart';
import 'labels.dart';
import 'widgets/common.dart';

enum _View { list, map }

/// Pharmacies as a list (nearest first) or on a map (`flutter_map`, OSM
/// tiles; markers work offline). Tap → details with directions.
class PharmaciesScreen extends ConsumerStatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  ConsumerState<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends ConsumerState<PharmaciesScreen> {
  _View _view = _View.list;
  bool _only24 = false;

  @override
  Widget build(BuildContext context) {
    final nearby = ref.watch(nearbyPharmaciesProvider);
    return AppScaffold(
      title: context.tr(uz: 'Dorixonalar', ru: 'Аптеки', en: 'Pharmacies'),
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<_View>(
                    segments: [
                      ButtonSegment(
                        value: _View.list,
                        icon: const Icon(Icons.list_rounded),
                        label: Text(
                          context.tr(uz: 'Ro‘yxat', ru: 'Список', en: 'List'),
                        ),
                      ),
                      ButtonSegment(
                        value: _View.map,
                        icon: const Icon(Icons.map_rounded),
                        label: Text(
                          context.tr(uz: 'Xarita', ru: 'Карта', en: 'Map'),
                        ),
                      ),
                    ],
                    selected: {_view},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _view = s.first),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('24/7'),
                  selected: _only24,
                  onSelected: (v) => setState(() => _only24 = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: nearby,
              onRetry: () => ref.invalidate(pharmaciesProvider),
              loading: () => const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: SkeletonList(count: 5),
              ),
              data: (all) {
                final list = [
                  for (final n in all)
                    if (!_only24 || n.pharmacy.open24) n,
                ];
                if (list.isEmpty) {
                  return EmptyState(
                    emoji: '🏪',
                    title: context.tr(
                      uz: 'Dorixona topilmadi',
                      ru: 'Аптеки не найдены',
                      en: 'No pharmacies found',
                    ),
                  );
                }
                return _view == _View.list
                    ? _PharmacyList(list: list)
                    : _PharmacyMap(list: list);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PharmacyList extends StatelessWidget {
  const _PharmacyList({required this.list});

  final List<NearbyPharmacy> list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final n = list[i];
        final p = n.pharmacy;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () => showPharmacySheet(context, n),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                EmojiBox(
                  emoji: '🏪',
                  color: p.open24 ? AppColors.good : AppColors.primary,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p.address != null)
                        Text(
                          p.address!,
                          style: text.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(hoursLabel(context, p), style: text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (n.distanceKm != null)
                      Text(
                        formatDistance(context, n.distanceKm!),
                        style: text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    if (p.rating != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.amber,
                          ),
                          Text(
                            p.rating!.toStringAsFixed(1),
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PharmacyMap extends ConsumerWidget {
  const _PharmacyMap({required this.list});

  final List<NearbyPharmacy> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final here = ref.watch(userLocationProvider).value;
    final tiles = ref.watch(pharmacyMapTilesProvider);
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: here ?? tashkentCenter,
          initialZoom: 12,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
        children: [
          if (tiles)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'uz.sino.sino',
            ),
          MarkerLayer(
            markers: [
              if (here != null)
                Marker(
                  point: here,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.sky,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              for (final n in list)
                Marker(
                  point: n.point,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => showPharmacySheet(context, n),
                    child: Tooltip(
                      message: n.pharmacy.name,
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 44,
                        color: n.pharmacy.open24
                            ? AppColors.good
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (tiles)
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
        ],
      ),
    );
  }
}

/// Pharmacy details with «Yo‘nalish» (opens a maps app).
Future<void> showPharmacySheet(BuildContext context, NearbyPharmacy n) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _PharmacySheet(n: n),
    );

class _PharmacySheet extends ConsumerWidget {
  const _PharmacySheet({required this.n});

  final NearbyPharmacy n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = n.pharmacy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.name,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (p.address != null) ...[
            const SizedBox(height: 4),
            Text(p.address!, style: text.bodyMedium),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                hoursLabel(context, p),
                color: p.open24 ? AppColors.good : AppColors.sky,
                icon: Icons.schedule_rounded,
              ),
              if (n.distanceKm != null)
                Pill(
                  formatDistance(context, n.distanceKm!),
                  icon: Icons.near_me_rounded,
                ),
              if (p.rating != null)
                Pill(
                  p.rating!.toStringAsFixed(1),
                  color: AppColors.amber,
                  icon: Icons.star_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              final ok = await ref.read(pharmacyLauncherProvider)(
                pharmacyMapsUri(p),
              );
              if (!ok && context.mounted) {
                showPharmacySnack(
                  context,
                  context.tr(
                    uz: 'Xaritani ochib bo‘lmadi',
                    ru: 'Не удалось открыть карту',
                    en: 'Couldn’t open the map',
                  ),
                );
              }
            },
            icon: const Icon(Icons.directions_rounded),
            label: Text(
              context.tr(uz: 'Yo‘nalish', ru: 'Маршрут', en: 'Directions'),
            ),
          ),
        ],
      ),
    );
  }
}
