import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/backend.dart';
import '../l10n/app_lang.dart';
import '../storage/prefs.dart';

/// The 8 badges of Sino. [code] is stored in `achievements.code`.
///
/// Who decides that a badge is earned: the home feature (it already reads
/// the whole day's data for the Sino index) — it unlocks via
/// [achievementsRepositoryProvider]. The profile shows them.
enum Achievement {
  firstWorkout('first_workout', '🏋️'),
  water7('water_7', '💧'),
  meds3('meds_3', '💊'),
  firstReservation('first_reservation', '🛍️'),
  steps10k('steps_10k', '👟'),
  index90('index_90', '🌟'),
  streak7('streak_7', '🔥'),
  fullDay('full_day', '🧩');

  const Achievement(this.code, this.emoji);

  final String code;
  final String emoji;

  static Achievement? byCode(String code) {
    for (final a in values) {
      if (a.code == code) return a;
    }
    return null;
  }

  String title(AppLang lang) => switch (this) {
    firstWorkout => lang.pick(
      'Birinchi mashg‘ulot',
      'Первая тренировка',
      'First workout',
    ),
    water7 => lang.pick('7 kun suv', '7 дней воды', '7 days of water'),
    meds3 => lang.pick(
      'Dorilar vaqtida',
      'Лекарства вовремя',
      'Medicines on time',
    ),
    firstReservation => lang.pick(
      'Birinchi bron',
      'Первая бронь',
      'First reservation',
    ),
    steps10k => lang.pick('10 000 qadam', '10 000 шагов', '10,000 steps'),
    index90 => lang.pick('Indeks 90+', 'Индекс 90+', 'Index 90+'),
    streak7 => lang.pick('Bir hafta seriya', 'Неделя подряд', 'A week streak'),
    fullDay => lang.pick('To‘liq kun', 'Полный день', 'Full day'),
  };

  /// How to earn it.
  String hint(AppLang lang) => switch (this) {
    firstWorkout => lang.pick(
      'Birinchi mashg‘ulotni oxirigacha bajaring',
      'Завершите первую тренировку',
      'Finish your first workout',
    ),
    water7 => lang.pick(
      '7 kun ketma-ket kuniga 8 stakan suv iching',
      '7 дней подряд выпивайте 8 стаканов воды',
      'Drink 8 glasses of water a day, 7 days in a row',
    ),
    meds3 => lang.pick(
      '3 kun ketma-ket barcha dorilarni vaqtida iching',
      '3 дня подряд принимайте все лекарства вовремя',
      'Take all your medicines on time 3 days in a row',
    ),
    firstReservation => lang.pick(
      'Dorixonada birinchi dorini bron qiling',
      'Забронируйте первое лекарство в аптеке',
      'Reserve your first medicine at a pharmacy',
    ),
    steps10k => lang.pick(
      'Bir kunda 10 000 qadam yuring',
      'Пройдите 10 000 шагов за день',
      'Walk 10,000 steps in a day',
    ),
    index90 => lang.pick(
      'Kunni Sino indeksi 90 va undan yuqori bilan yakunlang',
      'Завершите день с индексом Sino 90 и выше',
      'End a day with a Sino index of 90 or more',
    ),
    streak7 => lang.pick(
      '7 kun ketma-ket indeks 60 dan past bo‘lmasin',
      '7 дней подряд индекс не ниже 60',
      'Keep the index at 60 or more for 7 days in a row',
    ),
    fullDay => lang.pick(
      'Bir kunda ovqat, suv, dori, harakat va uyquni qayd eting',
      'За день отметьте еду, воду, лекарства, движение и сон',
      'Log food, water, medicines, activity and sleep in one day',
    ),
  };
}

extension on AppLang {
  String pick(String uz, String ru, String en) => switch (this) {
    AppLang.uz => uz,
    AppLang.ru => ru,
    AppLang.en => en,
  };
}

/// Unlocked badges of the current user (`achievements` table).
abstract class AchievementsRepository {
  /// Badge → when it was unlocked.
  Future<Map<Achievement, DateTime>> unlocked();

  /// Saves new badges; already unlocked ones are left as they are.
  Future<void> unlock(Iterable<Achievement> items, DateTime at);
}

class SupabaseAchievementsRepository implements AchievementsRepository {
  SupabaseAchievementsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<Achievement, DateTime>> unlocked() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const {};
    final rows = await _client
        .from('achievements')
        .select('code, unlocked_at')
        .eq('user_id', uid);
    return parseAchievementRows(rows);
  }

  @override
  Future<void> unlock(Iterable<Achievement> items, DateTime at) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || items.isEmpty) return;
    await _client
        .from('achievements')
        .upsert(
          [
            for (final a in items)
              {
                'user_id': uid,
                'code': a.code,
                'unlocked_at': at.toUtc().toIso8601String(),
              },
          ],
          onConflict: 'user_id,code',
          ignoreDuplicates: true,
        );
  }
}

/// `[{code, unlocked_at}]` → map; unknown codes are skipped.
Map<Achievement, DateTime> parseAchievementRows(
  List<Map<String, dynamic>> rows,
) => {
  for (final m in rows)
    ?Achievement.byCode(m['code'] as String): DateTime.parse(
      m['unlocked_at'] as String,
    ).toLocal(),
};

/// Fake mode: kept in prefs (`core.fake_achievements`: `{code: iso}`).
class FakeAchievementsRepository implements AchievementsRepository {
  FakeAchievementsRepository(this._ref);

  final Ref _ref;

  @override
  Future<Map<Achievement, DateTime>> unlocked() async {
    final raw = _ref
        .read(sharedPreferencesProvider)
        .getString(PrefKeys.fakeAchievements);
    if (raw == null) return const {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return parseAchievementRows([
      for (final e in map.entries) {'code': e.key, 'unlocked_at': e.value},
    ]);
  }

  @override
  Future<void> unlock(Iterable<Achievement> items, DateTime at) async {
    final current = await unlocked();
    final next = {
      for (final e in current.entries) e.key.code: e.value.toIso8601String(),
      for (final a in items)
        if (!current.containsKey(a)) a.code: at.toIso8601String(),
    };
    await _ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.fakeAchievements, jsonEncode(next));
  }
}

final achievementsRepositoryProvider = Provider<AchievementsRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeAchievementsRepository(ref)
      : SupabaseAchievementsRepository(ref.watch(supabaseClientProvider)),
);

/// Unlocked badges of the current user. Invalidate after
/// [AchievementsRepository.unlock].
final achievementsProvider = FutureProvider<Map<Achievement, DateTime>>((ref) {
  if (!ref.watch(useFakeProvider)) ref.watch(authStateProvider);
  return ref.watch(achievementsRepositoryProvider).unlocked();
});
