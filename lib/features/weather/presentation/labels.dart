import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../application/weather_logic.dart';

String skyText(BuildContext context, int code) => switch (skyOf(code)) {
  Sky.clear => context.tr(uz: 'Ochiq osmon', ru: 'Ясно', en: 'Clear'),
  Sky.partly => context.tr(
    uz: 'Qisman bulutli',
    ru: 'Переменная облачность',
    en: 'Partly cloudy',
  ),
  Sky.cloudy => context.tr(uz: 'Bulutli', ru: 'Пасмурно', en: 'Cloudy'),
  Sky.fog => context.tr(uz: 'Tuman', ru: 'Туман', en: 'Fog'),
  Sky.drizzle => context.tr(uz: 'Mayda yomg‘ir', ru: 'Морось', en: 'Drizzle'),
  Sky.rain => context.tr(uz: 'Yomg‘ir', ru: 'Дождь', en: 'Rain'),
  Sky.snow => context.tr(uz: 'Qor', ru: 'Снег', en: 'Snow'),
  Sky.showers => context.tr(uz: 'Jala', ru: 'Ливень', en: 'Showers'),
  Sky.storm => context.tr(uz: 'Momaqaldiroq', ru: 'Гроза', en: 'Thunderstorm'),
};

/// «Havo ifloslangan (AQI 156) — bugun uyda mashq qiling» — the same words
/// as the workouts generator uses.
String airAlertText(BuildContext context, AirAlert a) => context.tr(
  uz: 'Havo ifloslangan (AQI ${a.aqi}) — bugun uyda mashq qiling',
  ru: 'Воздух загрязнён (AQI ${a.aqi}) — сегодня тренируйтесь дома',
  en: 'The air is polluted (AQI ${a.aqi}) — work out at home today',
);

Color aqiColor(AqiLevel l) => switch (l) {
  AqiLevel.good => AppColors.good,
  AqiLevel.moderate => AppColors.amber,
  AqiLevel.sensitive => AppColors.coral,
  AqiLevel.unhealthy => AppColors.danger,
  AqiLevel.veryUnhealthy => AppColors.violet,
  AqiLevel.hazardous => Color.lerp(AppColors.garnet, AppColors.ink, 0.45)!,
};

/// Background of the weather hero by the time of day.
LinearGradient dayPartGradient(DayPart p) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: switch (p) {
    DayPart.morning => const [AppColors.coral, AppColors.sky],
    DayPart.day => const [AppColors.primary, AppColors.secondary],
    DayPart.evening => const [AppColors.coral, AppColors.violet],
    DayPart.night => const [AppColors.secondary, AppColors.backgroundDark],
  },
);

({String emoji, String text}) dayPartText(BuildContext context, DayPart p) =>
    switch (p) {
      DayPart.morning => (
        emoji: '🌅',
        text: context.tr(uz: 'Tong', ru: 'Утро', en: 'Morning'),
      ),
      DayPart.day => (
        emoji: '☀️',
        text: context.tr(uz: 'Kun', ru: 'День', en: 'Day'),
      ),
      DayPart.evening => (
        emoji: '🌇',
        text: context.tr(uz: 'Kech', ru: 'Вечер', en: 'Evening'),
      ),
      DayPart.night => (
        emoji: '🌙',
        text: context.tr(uz: 'Tun', ru: 'Ночь', en: 'Night'),
      ),
    };

String aqiText(BuildContext context, AqiLevel l) => switch (l) {
  AqiLevel.good => context.tr(uz: 'Yaxshi', ru: 'Хорошее', en: 'Good'),
  AqiLevel.moderate => context.tr(
    uz: 'O‘rtacha',
    ru: 'Умеренное',
    en: 'Moderate',
  ),
  AqiLevel.sensitive => context.tr(
    uz: 'Sezgir guruhlar uchun zararli',
    ru: 'Вредно для чувствительных групп',
    en: 'Unhealthy for sensitive groups',
  ),
  AqiLevel.unhealthy => context.tr(
    uz: 'Zararli',
    ru: 'Вредное',
    en: 'Unhealthy',
  ),
  AqiLevel.veryUnhealthy => context.tr(
    uz: 'Juda zararli',
    ru: 'Очень вредное',
    en: 'Very unhealthy',
  ),
  AqiLevel.hazardous => context.tr(
    uz: 'Xavfli',
    ru: 'Опасное',
    en: 'Hazardous',
  ),
};

({String emoji, String text}) tipText(BuildContext context, WeatherTip t) =>
    switch (t) {
      WeatherTip.airBad => (
        emoji: '😷',
        text: context.tr(
          uz:
              'Havo juda ifloslangan. Ochiq havoda mashq qilmang, derazalarni '
              'yoping; tashqariga chiqsangiz, N95 niqob taqing.',
          ru:
              'Воздух сильно загрязнён. Не тренируйтесь на улице, закройте '
              'окна; на улице — маска N95.',
          en:
              'The air is very polluted. Don’t train outside, keep windows '
              'closed; wear an N95 mask outdoors.',
        ),
      ),
      WeatherTip.airSensitive => (
        emoji: '🏠',
        text: context.tr(
          uz:
              'Bugun mashg‘ulotni uyda qiling. Astma, yurak kasalligi '
              'bo‘lganlar, bolalar va keksalar ko‘chada uzoq qolmasin.',
          ru:
              'Сегодня тренируйтесь дома. Людям с астмой, болезнями сердца, '
              'детям и пожилым не стоит долго быть на улице.',
          en:
              'Train at home today. People with asthma or heart disease, '
              'children and the elderly should limit time outside.',
        ),
      ),
      WeatherTip.rain => (
        emoji: '☔',
        text: context.tr(
          uz: 'Yaqin soatlarda yomg‘ir ehtimoli bor — soyabon oling.',
          ru: 'В ближайшие часы возможен дождь — возьмите зонт.',
          en: 'Rain is likely in the next hours — take an umbrella.',
        ),
      ),
      WeatherTip.heat => (
        emoji: '🥵',
        text: context.tr(
          uz:
              'Issiq. Ko‘proq suv iching, soyada yuring, mashg‘ulotni ertalab '
              'yoki kechqurun qiling.',
          ru:
              'Жарко. Пейте больше воды, держитесь в тени, тренируйтесь утром '
              'или вечером.',
          en:
              'It’s hot. Drink more water, stay in the shade, train in the '
              'morning or evening.',
        ),
      ),
      WeatherTip.cold => (
        emoji: '🧣',
        text: context.tr(
          uz: 'Sovuq. Qatlam-qatlam kiyining, badantarbiyani uzoqroq qiling.',
          ru: 'Холодно. Одевайтесь слоями, разминайтесь дольше.',
          en: 'It’s cold. Dress in layers and warm up longer.',
        ),
      ),
      WeatherTip.uv => (
        emoji: '🧴',
        text: context.tr(
          uz: 'UV yuqori — quyoshdan himoya kremi va bosh kiyim.',
          ru: 'Высокий УФ — солнцезащитный крем и головной убор.',
          en: 'High UV — use sunscreen and wear a hat.',
        ),
      ),
      WeatherTip.wind => (
        emoji: '💨',
        text: context.tr(
          uz: 'Kuchli shamol — velosiped va yugurishda ehtiyot bo‘ling.',
          ru: 'Сильный ветер — осторожнее на велосипеде и пробежке.',
          en: 'Strong wind — take care when cycling or running.',
        ),
      ),
      WeatherTip.goodDay => (
        emoji: '🚶',
        text: context.tr(
          uz: 'Sayr va ochiq havoda mashg‘ulot uchun yaxshi kun.',
          ru: 'Хороший день для прогулки и тренировки на улице.',
          en: 'A good day for a walk or an outdoor workout.',
        ),
      ),
    };

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Short weekday (1 = Monday).
String weekdayShort(BuildContext context, int weekday) {
  const uz = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  const ru = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final i = (weekday - 1).clamp(0, 6);
  return context.tr(uz: uz[i], ru: ru[i], en: en[i]);
}

/// «12°» (rounded, never «-0°»).
String deg(double t) {
  final r = t.round();
  return '${r == 0 ? 0 : r}°';
}

/// «5 daqiqa oldin», «3 soat oldin», else «18.11 08:12».
String agoText(BuildContext context, DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) {
    return context.tr(uz: 'hozirgina', ru: 'только что', en: 'just now');
  }
  if (d.inMinutes < 60) {
    final m = d.inMinutes;
    return context.tr(
      uz: '$m daqiqa oldin',
      ru: '$m мин назад',
      en: '$m min ago',
    );
  }
  if (d.inHours < 24) {
    final h = d.inHours;
    return context.tr(uz: '$h soat oldin', ru: '$h ч назад', en: '$h h ago');
  }
  final dd = at.day.toString().padLeft(2, '0');
  final mm = at.month.toString().padLeft(2, '0');
  return '$dd.$mm ${hhmm(at)}';
}
