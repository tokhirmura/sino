import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../data/models.dart';
import '../data/reminder_notifications.dart';
import '../data/reminders_repository.dart';
import 'reminder_schedule.dart';
import 'write_queue.dart';

enum ReminderProblem {
  /// Medicine name is empty.
  emptyName,

  /// No weekday selected.
  noDays,

  /// «Taken» for a day in the future.
  futureDose,
}

class ReminderException implements Exception {
  const ReminderException(this.problem);

  final ReminderProblem problem;

  @override
  String toString() => 'ReminderException(${problem.name})';
}

/// The user's reminders by time, with optimistic add / update / remove.
/// After every confirmed change (and on load) the local notifications are
/// re-synced.
class RemindersNotifier extends AsyncNotifier<List<Reminder>> {
  final _queue = WriteQueue();

  /// Throws if the UI must not be updated (load failed); waits while
  /// loading so an optimistic change is not lost when the load completes.
  Future<void> _ready() async {
    final err = state.error;
    if (state.hasError && err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    if (state.isLoading) await future;
  }

  RemindersRepository get _repo => ref.read(remindersRepositoryProvider);

  List<Reminder> get _current => state.value ?? const [];

  @override
  Future<List<Reminder>> build() async {
    ref.watch(authStateProvider);
    final list = await ref.watch(remindersRepositoryProvider).reminders();
    unawaited(_sync(list));
    return list;
  }

  static void _validate(Reminder r) {
    if (r.name.trim().isEmpty) {
      throw const ReminderException(ReminderProblem.emptyName);
    }
    if (r.days.isEmpty) throw const ReminderException(ReminderProblem.noDays);
  }

  static List<Reminder> _sorted(List<Reminder> l) => [...l]
    ..sort((a, b) {
      final c = a.minuteOfDay.compareTo(b.minuteOfDay);
      return c != 0 ? c : a.name.compareTo(b.name);
    });

  Future<Reminder> add(Reminder draft) async {
    _validate(draft);
    await _ready();
    if (!ref.mounted) return draft;
    final temp = draft.copyWith(id: newPendingId(), createdAt: DateTime.now());
    state = AsyncData(_sorted([..._current, temp]));
    try {
      final saved = await _queue.run(() => _repo.add(draft));
      if (ref.mounted) {
        state = AsyncData(
          _sorted([
            for (final r in _current)
              if (r.id != temp.id) r,
            saved,
          ]),
        );
        unawaited(_sync(_current));
      }
      return saved;
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData([
          for (final r in _current)
            if (r.id != temp.id) r,
        ]);
      }
      rethrow;
    }
  }

  Future<void> edit(Reminder reminder) async {
    _validate(reminder);
    await _ready();
    final old = _find(reminder.id);
    if (old == null || isPendingId(reminder.id) || !ref.mounted) return;
    _replace(reminder);
    try {
      final saved = await _queue.run(() => _repo.update(reminder));
      if (ref.mounted) {
        _replace(saved);
        unawaited(_sync(_current));
      }
    } catch (_) {
      if (ref.mounted && identical(_find(reminder.id), reminder)) {
        _replace(old);
      }
      rethrow;
    }
  }

  Future<void> setActive(String id, bool active) async {
    final r = _find(id);
    if (r == null || r.active == active) return;
    await edit(r.copyWith(active: active));
  }

  /// Removes the reminder (and its history). Returns it, or `null`.
  Future<Reminder?> remove(String id) async {
    await _ready();
    final removed = _find(id);
    if (removed == null || isPendingId(id) || !ref.mounted) return null;
    state = AsyncData([
      for (final r in _current)
        if (r.id != id) r,
    ]);
    try {
      await _queue.run(() => _repo.remove(id));
      if (ref.mounted) {
        ref.invalidate(reminderLogsProvider);
        unawaited(_sync(_current));
      }
      return removed;
    } catch (_) {
      if (ref.mounted) state = AsyncData(_sorted([..._current, removed]));
      rethrow;
    }
  }

  Reminder? _find(String id) {
    for (final r in _current) {
      if (r.id == id) return r;
    }
    return null;
  }

  void _replace(Reminder r) => state = AsyncData(
    _sorted([for (final x in _current) x.id == r.id ? r : x]),
  );

  Future<void> _sync(List<Reminder> list) async {
    final notifications = ref.read(reminderNotificationsProvider);
    final lang = ref.read(appLangProvider);
    var names = const <String, String>{};
    try {
      final members = await ref.read(familyMembersProvider.future);
      names = {for (final m in members) m.id: m.name};
    } catch (_) {
      // Names are optional in the notification text.
    }
    await notifications.sync(
      [
        for (final r in list)
          if (!isPendingId(r.id)) r,
      ],
      lang: lang,
      memberNames: names,
    );
  }
}

final remindersProvider =
    AsyncNotifierProvider<RemindersNotifier, List<Reminder>>(
      RemindersNotifier.new,
    );

/// How far back the intake history is loaded (days before today).
const reminderHistoryDays = 30;

/// Intake logs of the last [reminderHistoryDays] days, oldest first, with
/// optimistic «taken» / undo.
class ReminderLogsNotifier extends AsyncNotifier<List<ReminderLog>> {
  final _queue = WriteQueue();

  /// Throws if the UI must not be updated (load failed); waits while
  /// loading so an optimistic change is not lost when the load completes.
  Future<void> _ready() async {
    final err = state.error;
    if (state.hasError && err != null) {
      Error.throwWithStackTrace(err, state.stackTrace ?? StackTrace.current);
    }
    if (state.isLoading) await future;
  }

  RemindersRepository get _repo => ref.read(remindersRepositoryProvider);

  List<ReminderLog> get _current => state.value ?? const [];

  @override
  Future<List<ReminderLog>> build() {
    ref.watch(authStateProvider);
    final today = dayOf(DateTime.now());
    return ref
        .watch(remindersRepositoryProvider)
        .logsSince(
          DateTime(today.year, today.month, today.day - reminderHistoryDays),
        );
  }

  /// Marks [reminder]'s dose on [day] as taken (at [at], default: now for
  /// today, the scheduled time for a past day). Already taken → the
  /// existing log, no write.
  Future<ReminderLog> markTaken(
    Reminder reminder,
    DateTime day, {
    DateTime? at,
  }) async {
    final now = DateTime.now();
    final d = dayOf(day);
    if (d.isAfter(dayOf(now))) {
      throw const ReminderException(ReminderProblem.futureDose);
    }
    await _ready();
    final existing = logFor(reminder, d, _current);
    if (existing != null) return existing;
    final takenAt = at ?? (d == dayOf(now) ? now : reminder.at(d));
    final temp = ReminderLog(
      id: newPendingId(),
      reminderId: reminder.id,
      takenAt: takenAt,
    );
    if (ref.mounted) state = AsyncData([..._current, temp]);
    try {
      final saved = await _queue.run(
        () => _repo.logTaken(reminder.id, takenAt),
      );
      if (ref.mounted) {
        state = AsyncData([
          for (final l in _current) l.id == temp.id ? saved : l,
        ]);
      }
      return saved;
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData([
          for (final l in _current)
            if (l.id != temp.id) l,
        ]);
      }
      rethrow;
    }
  }

  /// Undo of [markTaken].
  Future<void> undo(String logId) async {
    await _ready();
    ReminderLog? removed;
    for (final l in _current) {
      if (l.id == logId) removed = l;
    }
    if (removed == null || isPendingId(logId) || !ref.mounted) return;
    state = AsyncData([
      for (final l in _current)
        if (l.id != logId) l,
    ]);
    try {
      await _queue.run(() => _repo.removeLog(logId));
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(
          [..._current, removed]
            ..sort((a, b) => a.takenAt.compareTo(b.takenAt)),
        );
      }
      rethrow;
    }
  }
}

final reminderLogsProvider =
    AsyncNotifierProvider<ReminderLogsNotifier, List<ReminderLog>>(
      ReminderLogsNotifier.new,
    );

/// Both values ready → [combine]; any error → that error; else loading.
AsyncValue<R> _both<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A, B) combine,
) {
  for (final v in [a, b]) {
    if (v.hasError) {
      return AsyncError<R>(v.error!, v.stackTrace ?? StackTrace.current);
    }
  }
  if (!a.hasValue || !b.hasValue) return AsyncLoading<R>();
  return AsyncData(combine(a.requireValue, b.requireValue));
}

/// Doses of one day by time. Pass the date without time (`dayOf(...)`).
final dosesForDayProvider = Provider.family<AsyncValue<List<Dose>>, DateTime>(
  (ref, day) => _both(
    ref.watch(remindersProvider),
    ref.watch(reminderLogsProvider),
    (rs, ls) => dosesForDay(day, rs, ls),
  ),
);

/// The next dose to take (home card), `null` when none in a week.
final nextDoseProvider = Provider<AsyncValue<Dose?>>(
  (ref) => _both(
    ref.watch(remindersProvider),
    ref.watch(reminderLogsProvider),
    (rs, ls) => nextDose(DateTime.now(), rs, ls),
  ),
);

/// Adherence over the last 7 days.
final adherenceProvider = Provider<AsyncValue<Adherence>>(
  (ref) => _both(
    ref.watch(remindersProvider),
    ref.watch(reminderLogsProvider),
    (rs, ls) => adherence(DateTime.now(), rs, ls),
  ),
);

/// A history row: a log with its reminder (`null` if it was deleted).
class IntakeEntry {
  const IntakeEntry(this.log, this.reminder);

  final ReminderLog log;
  final Reminder? reminder;
}

/// Intake history, newest first.
final intakeHistoryProvider = Provider<AsyncValue<List<IntakeEntry>>>(
  (ref) => _both(
    ref.watch(remindersProvider),
    ref.watch(reminderLogsProvider),
    (rs, ls) {
      final byId = {for (final r in rs) r.id: r};
      return [
        for (final l in ls.reversed)
          if (!isPendingId(l.id)) IntakeEntry(l, byId[l.reminderId]),
      ];
    },
  ),
);
