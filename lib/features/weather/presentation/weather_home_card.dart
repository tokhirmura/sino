import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/emoji_box.dart';
import '../../../core/widgets/pill.dart';
import '../application/weather_logic.dart';
import '../application/weather_providers.dart';
import 'labels.dart';

/// Home card: temperature, sky and AQI of the selected place; with bad air
/// — «train at home today».
class WeatherHomeCard extends ConsumerWidget {
  const WeatherHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(weatherReportProvider);
    void open() => context.push(AppRoutes.weather);
    final title = context.tr(uz: 'Ob-havo', ru: 'Погода', en: 'Weather');

    final r = report.value;
    if (r == null) {
      return ShortcutCard(
        key: const Key('weather-home-card'),
        emoji: '🌤️',
        title: title,
        subtitle: report.hasError
            ? context.tr(
                uz: 'Ma’lumot yuklanmadi — ochib qayta urinib ko‘ring',
                ru: 'Не удалось загрузить — откройте и повторите',
                en: 'Couldn’t load — open to retry',
              )
            : context.tr(uz: 'Yuklanmoqda…', ru: 'Загрузка…', en: 'Loading…'),
        color: AppColors.sky,
        onTap: open,
      );
    }

    final text = Theme.of(context).textTheme;
    final c = r.current;
    final air = r.air;
    final level = air == null ? null : AqiLevel.of(air.aqi);
    final bad = air != null && air.aqi > outdoorAqiLimit;

    return AppCard(
      key: const Key('weather-home-card'),
      onTap: open,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          EmojiBox(
            emoji: skyEmoji(c.code, isDay: c.isDay),
            color: AppColors.sky,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${deg(c.temp)} · ${context.trMap(r.place.name)}',
                  key: const Key('weather-home-temp'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  bad
                      ? tipText(
                          context,
                          WeatherTip.airSensitive,
                        ).text.split('.').first
                      : [
                          skyText(context, c.code),
                          if (r.fromCache)
                            context.tr(
                              uz: 'oflayn',
                              ru: 'офлайн',
                              en: 'offline',
                            ),
                        ].join(' · '),
                  key: const Key('weather-home-subtitle'),
                  style: text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (air != null) ...[
            const SizedBox(width: 8),
            Pill(
              'AQI ${air.aqi}',
              key: const Key('weather-home-aqi'),
              color: aqiColor(level!),
            ),
          ],
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
