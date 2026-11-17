import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/section_title.dart';
import '../application/weather_logic.dart';
import '../application/weather_providers.dart';
import '../data/models.dart';
import 'labels.dart';

/// Weather and air quality of the selected city or of «my location», with
/// advice for walks and outdoor workouts. Offline — the last saved forecast.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(weatherReportProvider);
    final placeId = ref.watch(weatherPlaceProvider);

    Future<void> refresh() async {
      ref.invalidate(weatherReportProvider);
      await ref
          .read(weatherReportProvider.future)
          .then<void>((_) {}, onError: (Object _) {});
    }

    return AppScaffold(
      title: context.tr(uz: 'Ob-havo', ru: 'Погода', en: 'Weather'),
      actions: [
        IconButton(
          key: const Key('weather-refresh'),
          tooltip: context.tr(uz: 'Yangilash', ru: 'Обновить', en: 'Refresh'),
          onPressed: report.isLoading ? null : refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _PlacePicker(selected: placeId),
            const SizedBox(height: 12),
            report.when(
              loading: () => const SkeletonList(count: 3, itemHeight: 140),
              error: (e, _) => e is LocationUnavailableException
                  ? EmptyState(
                      emoji: '📍',
                      title: context.tr(
                        uz: 'Joylashuv aniqlanmadi',
                        ru: 'Не удалось определить местоположение',
                        en: 'Couldn’t get your location',
                      ),
                      message: context.tr(
                        uz:
                            'Geolokatsiyani yoqing va ruxsat bering yoki '
                            'yuqoridan shaharni tanlang.',
                        ru:
                            'Включите геолокацию и дайте доступ или выберите '
                            'город выше.',
                        en:
                            'Turn on location and allow access, or pick a city '
                            'above.',
                      ),
                      action: FilledButton(
                        onPressed: refresh,
                        child: Text(
                          context.tr(
                            uz: 'Qayta urinish',
                            ru: 'Повторить',
                            en: 'Retry',
                          ),
                        ),
                      ),
                    )
                  : ErrorView(error: e, onRetry: refresh),
              data: (r) => _ReportView(report: r, selectedId: placeId),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacePicker extends ConsumerWidget {
  const _PlacePicker({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void pick(String id) => ref.read(weatherPlaceProvider.notifier).select(id);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: const Key('weather-place-gps'),
              avatar: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                context.tr(uz: 'Joylashuvim', ru: 'Где я', en: 'My location'),
              ),
              selected: selected == gpsPlaceId,
              onSelected: (_) => pick(gpsPlaceId),
            ),
          ),
          for (final c in weatherCities)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('weather-place-${c.id}'),
                label: Text(context.trMap(c.name)),
                selected: selected == c.id,
                onSelected: (_) => pick(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report, required this.selectedId});

  final WeatherReport report;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final text = Theme.of(context).textTheme;
    final tips = weatherTips(r);
    final otherPlace = r.place.id != selectedId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (r.fromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              key: const Key('weather-offline'),
              elevated: false,
              color: AppColors.amber.withValues(alpha: 0.14),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppColors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      otherPlace
                          ? context.tr(
                              uz:
                                  'Internet yo‘q. Bu shahar uchun saqlangan '
                                  'prognoz yo‘q — oxirgi saqlangani: '
                                  '${context.trMap(r.place.name)}, '
                                  '${agoText(context, r.fetchedAt, DateTime.now())}.',
                              ru:
                                  'Нет интернета. Для этого города прогноза '
                                  'нет — последний сохранённый: '
                                  '${context.trMap(r.place.name)}, '
                                  '${agoText(context, r.fetchedAt, DateTime.now())}.',
                              en:
                                  'No internet. Nothing saved for this city — '
                                  'the last saved forecast: '
                                  '${context.trMap(r.place.name)}, '
                                  '${agoText(context, r.fetchedAt, DateTime.now())}.',
                            )
                          : context.tr(
                              uz:
                                  'Internet yo‘q — oxirgi saqlangan prognoz '
                                  '(${agoText(context, r.fetchedAt, DateTime.now())}).',
                              ru:
                                  'Нет интернета — последний сохранённый '
                                  'прогноз (${agoText(context, r.fetchedAt, DateTime.now())}).',
                              en:
                                  'No internet — the last saved forecast '
                                  '(${agoText(context, r.fetchedAt, DateTime.now())}).',
                            ),
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        _NowCard(report: r),
        const SizedBox(height: 12),
        if (r.air != null) ...[
          _AirCard(air: r.air!),
          const SizedBox(height: 12),
        ],
        SectionTitle(
          context.tr(
            uz: 'Sayr va mashg‘ulot uchun',
            ru: 'Для прогулки и тренировки',
            en: 'For walks and workouts',
          ),
        ),
        AppCard(
          key: const Key('weather-tips'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final t in tips)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tipText(context, t).emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tipText(context, t).text,
                          key: Key('weather-tip-${t.name}'),
                          style: text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (r.hours.isNotEmpty) ...[
          SectionTitle(
            context.tr(uz: 'Soatlar bo‘yicha', ru: 'По часам', en: 'Hourly'),
          ),
          _Hours(hours: r.hours),
        ],
        if (r.days.isNotEmpty) ...[
          SectionTitle(
            context.tr(uz: '7 kunlik', ru: 'На 7 дней', en: '7 days'),
          ),
          _Days(days: r.days),
        ],
        const SizedBox(height: 16),
        Text(
          context.tr(
            uz:
                'Ma’lumot: Open-Meteo. Havo sifati — US AQI. Maslahatlar umumiy; '
                'shifokor maslahatini almashtirmaydi.',
            ru:
                'Данные: Open-Meteo. Качество воздуха — US AQI. Советы общие; '
                'не заменяют консультацию врача.',
            en:
                'Data: Open-Meteo. Air quality — US AQI. The advice is general; '
                'it does not replace a doctor’s advice.',
          ),
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final c = report.current;
    final text = Theme.of(context).textTheme;
    const white = Colors.white;
    final night = !c.isDay;
    final place = context.trMap(report.place.name);
    return AppCard(
      key: const Key('weather-now'),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: night
            ? const [Color(0xFF1E3A8A), Color(0xFF6D28D9)]
            : const [AppColors.sky, Color(0xFF6366F1)],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (report.place.isGps) ...[
                  const Icon(Icons.my_location_rounded, color: white, size: 16),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    report.place.isGps
                        ? context.tr(
                            uz: 'Joylashuvim · $place',
                            ru: 'Где я · $place',
                            en: 'My location · $place',
                          )
                        : place,
                    key: const Key('weather-place'),
                    style: text.titleMedium?.copyWith(
                      color: white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${context.tr(uz: 'Yangilandi', ru: 'Обновлено', en: 'Updated')} '
                  '${agoText(context, report.fetchedAt, DateTime.now())}',
                  style: text.bodySmall?.copyWith(
                    color: white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  skyEmoji(c.code, isDay: c.isDay),
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(width: 12),
                Text(
                  deg(c.temp),
                  key: const Key('weather-temp'),
                  style: text.displayMedium?.copyWith(
                    color: white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skyText(context, c.code),
                        style: text.titleSmall?.copyWith(color: white),
                      ),
                      Text(
                        context.tr(
                          uz: 'Seziladi ${deg(c.feelsLike)}',
                          ru: 'Ощущается ${deg(c.feelsLike)}',
                          en: 'Feels like ${deg(c.feelsLike)}',
                        ),
                        style: text.bodySmall?.copyWith(color: white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _Stat(icon: Icons.water_drop_outlined, value: '${c.humidity}%'),
                _Stat(
                  icon: Icons.air_rounded,
                  value:
                      '${c.wind.round()} ${context.tr(uz: 'km/soat', ru: 'км/ч', en: 'km/h')}',
                ),
                if (report.days.isNotEmpty)
                  _Stat(
                    icon: Icons.thermostat_rounded,
                    value:
                        '${deg(report.days.first.min)} … ${deg(report.days.first.max)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Colors.white),
      const SizedBox(width: 4),
      Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Colors.white),
      ),
    ],
  );
}

class _AirCard extends StatelessWidget {
  const _AirCard({required this.air});

  final AirQuality air;

  @override
  Widget build(BuildContext context) {
    final level = AqiLevel.of(air.aqi);
    final color = aqiColor(level);
    final text = Theme.of(context).textTheme;
    final bad = air.aqi > outdoorAqiLimit;
    return AppCard(
      key: const Key('weather-air'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
                child: Text(
                  '${air.aqi}',
                  key: const Key('weather-aqi'),
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        uz: 'Havo sifati (AQI)',
                        ru: 'Качество воздуха (AQI)',
                        en: 'Air quality (AQI)',
                      ),
                      style: text.bodySmall,
                    ),
                    Text(
                      aqiText(context, level),
                      key: const Key('weather-aqi-level'),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if (air.pm25 != null || air.pm10 != null)
                      Text(
                        [
                          if (air.pm25 != null) 'PM2.5 ${air.pm25!.round()}',
                          if (air.pm10 != null) 'PM10 ${air.pm10!.round()}',
                        ].join(' · '),
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (bad) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('weather-home-workout'),
              onPressed: () => context.go(AppRoutes.workouts),
              icon: const Icon(Icons.home_rounded),
              label: Text(
                context.tr(
                  uz: 'Uyda mashg‘ulot',
                  ru: 'Тренировка дома',
                  en: 'Work out at home',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Hours extends StatelessWidget {
  const _Hours({required this.hours});

  final List<HourWeather> hours;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 112,
      child: ListView.separated(
        key: const Key('weather-hours'),
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final h = hours[i];
          return AppCard(
            elevated: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  i == 0
                      ? context.tr(uz: 'Hozir', ru: 'Сейчас', en: 'Now')
                      : hhmm(h.time),
                  style: text.bodySmall,
                ),
                Text(
                  skyEmoji(h.code, isDay: h.time.hour >= 7 && h.time.hour < 18),
                  style: const TextStyle(fontSize: 22),
                ),
                Text(
                  deg(h.temp),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  h.precipChance > 0 ? '💧${h.precipChance}%' : ' ',
                  style: text.labelSmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Days extends StatelessWidget {
  const _Days({required this.days});

  final List<DayWeather> days;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      key: const Key('weather-days'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      i == 0
                          ? context.tr(uz: 'Bugun', ru: 'Сегодня', en: 'Today')
                          : weekdayShort(context, days[i].date.weekday),
                      style: text.titleSmall,
                    ),
                  ),
                  Text(
                    skyEmoji(days[i].code),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      days[i].precipChance > 0
                          ? '💧${days[i].precipChance}%'
                          : '',
                      style: text.labelSmall,
                    ),
                  ),
                  const Spacer(),
                  Text(deg(days[i].min), style: text.bodyMedium),
                  const SizedBox(width: 8),
                  Text(
                    deg(days[i].max),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
