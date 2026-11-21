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
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/models.dart';
import '../application/pharmacy_providers.dart';
import '../data/external_launcher.dart';
import '../data/location_repository.dart';
import 'labels.dart';
import 'widgets/common.dart';
import 'widgets/motion.dart';

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
                child: SkeletonLoader(count: 5),
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
            animate: false,
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
                          color: theme.colorScheme.primary,
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
        ).staggerIn(i);
      },
    );
  }
}

class _PharmacyMap extends ConsumerStatefulWidget {
  const _PharmacyMap({required this.list});

  final List<NearbyPharmacy> list;

  @override
  ConsumerState<_PharmacyMap> createState() => _PharmacyMapState();
}

class _PharmacyMapState extends ConsumerState<_PharmacyMap> {
  String? _selectedId;

  NearbyPharmacy? get _selected {
    for (final n in widget.list) {
      if (n.pharmacy.id == _selectedId) return n;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final here = ref.watch(userLocationProvider).value;
    final tiles = ref.watch(pharmacyMapTilesProvider);
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected;
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: here ?? tashkentCenter,
                initialZoom: 12,
                backgroundColor: scheme.surfaceContainerHighest,
                // Tap on the map itself closes the card.
                onTap: (_, _) => setState(() => _selectedId = null),
              ),
              children: [
                if (tiles)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'uz.sino.sino',
                  ),
                MarkerLayer(
                  markers: [
                    if (here != null)
                      Marker(
                        point: here,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: AppShadows.glow(AppColors.secondary),
                          ),
                        ),
                      ),
                    for (final n in widget.list)
                      Marker(
                        point: n.point,
                        width: 60,
                        height: 64,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedId = n.pharmacy.id),
                          child: Tooltip(
                            message: n.pharmacy.name,
                            child: PharmacyPin(
                              key: ValueKey('pharmacy-pin-${n.pharmacy.id}'),
                              open24: n.pharmacy.open24,
                              selected: n.pharmacy.id == _selectedId,
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
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: AnimatedSwitcher(
            duration: AppMotion.medium,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) => SlideTransition(
              position: Tween(
                begin: const Offset(0, 1.3),
                end: Offset.zero,
              ).animate(a),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: selected == null
                ? const SizedBox(key: ValueKey('no-selection'), width: 1)
                : _SelectedPharmacyCard(
                    key: ValueKey('selected-${selected.pharmacy.id}'),
                    n: selected,
                    onClose: () => setState(() => _selectedId = null),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Map pin in the brand colors: a gradient drop with a white ring and a
/// pharmacy icon; 24/7 pharmacies are green. The selected one grows and
/// glows.
class PharmacyPin extends StatelessWidget {
  const PharmacyPin({super.key, required this.open24, required this.selected});

  final bool open24;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final gradient = open24
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.good,
              AppColors.readable(AppColors.good, Brightness.light),
            ],
          )
        : AppColors.brand(brightness);
    final glow = open24 ? AppColors.good : AppColors.secondary;
    return AnimatedScale(
      scale: selected ? 1.25 : 1,
      duration: AppMotion.fast,
      curve: Curves.easeOutBack,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              border: Border.all(
                color: selected ? AppColors.saffron : Colors.white,
                width: 3,
              ),
              boxShadow: selected
                  ? AppShadows.glow(glow)
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: const Icon(
              Icons.local_pharmacy_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          // The tip of the drop points at the pharmacy.
          CustomPaint(
            size: const Size(14, 9),
            painter: _PinTip(selected ? AppColors.saffron : Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PinTip extends CustomPainter {
  const _PinTip(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTip old) => old.color != color;
}

/// The tapped pharmacy, slid up over the map.
class _SelectedPharmacyCard extends ConsumerWidget {
  const _SelectedPharmacyCard({
    super.key,
    required this.n,
    required this.onClose,
  });

  final NearbyPharmacy n;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = n.pharmacy;
    return AppCard(
      animate: false,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.address != null)
                      Text(
                        p.address!,
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr(uz: 'Yopish', ru: 'Закрыть', en: 'Close'),
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Tag(
                  hoursLabel(context, p),
                  color: p.open24 ? AppColors.good : AppColors.sky,
                  icon: Icons.schedule_rounded,
                ),
                if (n.distanceKm != null)
                  Tag(
                    formatDistance(context, n.distanceKm!),
                    icon: Icons.near_me_rounded,
                  ),
                if (p.rating != null)
                  Tag(
                    p.rating!.toStringAsFixed(1),
                    color: AppColors.amber,
                    icon: Icons.star_rounded,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PrimaryButton(
              height: 50,
              icon: Icons.directions_rounded,
              label: context.tr(
                uz: 'Yo‘nalish',
                ru: 'Маршрут',
                en: 'Directions',
              ),
              onPressed: () => openPharmacyDirections(context, ref, p),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens directions to [p] in a maps app; a snack if none could open.
Future<void> openPharmacyDirections(
  BuildContext context,
  WidgetRef ref,
  Pharmacy p,
) async {
  final ok = await ref.read(pharmacyLauncherProvider)(pharmacyMapsUri(p));
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
              Tag(
                hoursLabel(context, p),
                color: p.open24 ? AppColors.good : AppColors.sky,
                icon: Icons.schedule_rounded,
              ),
              if (n.distanceKm != null)
                Tag(
                  formatDistance(context, n.distanceKm!),
                  icon: Icons.near_me_rounded,
                ),
              if (p.rating != null)
                Tag(
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
            onPressed: () => openPharmacyDirections(context, ref, p),
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
