import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/emoji_box.dart';

/// One quick service. `tab: true` switches a bottom tab (`go`),
/// otherwise the screen is pushed full-screen.
class _Service {
  const _Service(this.route, this.emoji, this.color, this.label, {this.tab});

  final String route;
  final String emoji;
  final Color color;
  final String Function(BuildContext) label;
  final bool? tab;
}

final _services = <_Service>[
  _Service(
    AppRoutes.pharmacy,
    '💊',
    AppColors.primary,
    (c) => c.tr(uz: 'Dorixona', ru: 'Аптека', en: 'Pharmacy'),
    tab: true,
  ),
  _Service(
    AppRoutes.doctors,
    '🩺',
    AppColors.sky,
    (c) => c.tr(uz: 'Shifokorlar', ru: 'Врачи', en: 'Doctors'),
  ),
  _Service(
    AppRoutes.reminders,
    '⏰',
    AppColors.amber,
    (c) => c.tr(uz: 'Eslatmalar', ru: 'Напоминания', en: 'Reminders'),
  ),
  _Service(
    AppRoutes.nutrition,
    '🥗',
    AppColors.good,
    (c) => c.tr(uz: 'Ovqat', ru: 'Питание', en: 'Nutrition'),
    tab: true,
  ),
  _Service(
    AppRoutes.workouts,
    '🏃',
    AppColors.coral,
    (c) => c.tr(uz: 'Sport', ru: 'Спорт', en: 'Workouts'),
    tab: true,
  ),
  _Service(
    AppRoutes.vitals,
    '❤️',
    AppColors.danger,
    (c) => c.tr(uz: 'Ko‘rsatkichlar', ru: 'Показатели', en: 'Vitals'),
  ),
  _Service(
    AppRoutes.weather,
    '🌤️',
    AppColors.sky,
    (c) => c.tr(uz: 'Havo', ru: 'Погода', en: 'Weather'),
  ),
  _Service(
    AppRoutes.assistant,
    '🤖',
    AppColors.violet,
    (c) => c.tr(uz: 'Yordamchi', ru: 'Ассистент', en: 'Assistant'),
  ),
  _Service(
    AppRoutes.sos,
    '🆘',
    AppColors.danger,
    (c) => c.tr(uz: 'SOS', ru: 'SOS', en: 'SOS'),
  ),
];

/// Routes covered by the grid (for tests).
List<String> get quickServiceRoutes => [for (final s in _services) s.route];

/// 3×3 grid of shortcuts to every feature screen.
class ServicesGrid extends StatelessWidget {
  const ServicesGrid({super.key});

  static const columns = 3;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: [for (final s in _services) _ServiceTile(service: s)],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final _Service service;

  @override
  Widget build(BuildContext context) {
    final label = service.label(context);
    final radius = BorderRadius.circular(AppColors.cardRadius);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: radius,
        child: InkWell(
          key: ValueKey('service-${service.route}'),
          borderRadius: radius,
          onTap: () => service.tab == true
              ? context.go(service.route)
              : context.push(service.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmojiBox(emoji: service.emoji, color: service.color, size: 44),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
