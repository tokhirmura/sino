import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/backend.dart';
import '../storage/prefs.dart';
import 'health_goal.dart';

export 'health_goal.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    this.birthYear,
    this.heightCm,
    this.weightKg,
    this.bloodType,
    this.allergies = const [],
    this.lang = 'uz',
    this.goal,
  });

  final String id;
  final String fullName;
  final int? birthYear;
  final double? heightCm;
  final double? weightKg;
  final String? bloodType;
  final List<String> allergies;
  final String lang;

  /// Main goal (`profiles.goal`); `null` — not chosen yet (optional).
  final HealthGoal? goal;

  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  /// First-run questionnaire filled (name, birth year, height, weight).
  /// Until then the router keeps the user on `AppRoutes.profileSetup`.
  bool get isComplete =>
      fullName.trim().isNotEmpty &&
      birthYear != null &&
      heightCm != null &&
      weightKg != null;

  UserProfile copyWith({
    String? fullName,
    int? birthYear,
    double? heightCm,
    double? weightKg,
    String? bloodType,
    List<String>? allergies,
    String? lang,
    HealthGoal? goal,
  }) => UserProfile(
    id: id,
    fullName: fullName ?? this.fullName,
    birthYear: birthYear ?? this.birthYear,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    bloodType: bloodType ?? this.bloodType,
    allergies: allergies ?? this.allergies,
    lang: lang ?? this.lang,
    goal: goal ?? this.goal,
  );

  /// Row for `profiles` (column names as in the DB).
  Map<String, dynamic> toMap() => {
    'id': id,
    'full_name': fullName,
    'birth_year': birthYear,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'blood_type': bloodType,
    'allergies': allergies,
    'lang': lang,
    // Only when chosen: saving other fields never clears it.
    'goal': ?goal?.code,
  };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    id: m['id'] as String,
    fullName: (m['full_name'] as String?) ?? '',
    birthYear: m['birth_year'] as int?,
    heightCm: (m['height_cm'] as num?)?.toDouble(),
    weightKg: (m['weight_kg'] as num?)?.toDouble(),
    bloodType: m['blood_type'] as String?,
    allergies: List<String>.from(m['allergies'] as List? ?? const []),
    lang: (m['lang'] as String?) ?? 'uz',
    goal: HealthGoal.byCode(m['goal']),
  );

  static final fake = UserProfile(
    id: 'fake-user',
    fullName: 'Aziz',
    birthYear: DateTime.now().year - 29,
    heightCm: 178,
    weightKg: 76,
    bloodType: 'A(II) Rh+',
    allergies: const ['Penitsillin'],
  );
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    this.birthYear,
    this.bloodType,
    this.allergies = const [],
  });

  final String id;
  final String name;
  final String relation;
  final int? birthYear;
  final String? bloodType;
  final List<String> allergies;

  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  /// Row for `family_members` without `id` / `user_id` (set by the caller).
  Map<String, dynamic> toMap() => {
    'name': name,
    'relation': relation,
    'birth_year': birthYear,
    'blood_type': bloodType,
    'allergies': allergies,
  };

  factory FamilyMember.fromMap(Map<String, dynamic> m) => FamilyMember(
    id: m['id'] as String,
    name: m['name'] as String,
    relation: m['relation'] as String,
    birthYear: m['birth_year'] as int?,
    bloodType: m['blood_type'] as String?,
    allergies: List<String>.from(m['allergies'] as List? ?? const []),
  );

  static final fakes = [
    FamilyMember(
      id: 'fake-mother',
      name: 'Dilfuza',
      relation: 'ona',
      birthYear: DateTime.now().year - 56,
      bloodType: 'B(III) Rh+',
    ),
    FamilyMember(
      id: 'fake-father',
      name: 'Akbar',
      relation: 'ota',
      birthYear: DateTime.now().year - 60,
      bloodType: 'A(II) Rh+',
      allergies: const ['Aspirin'],
    ),
    FamilyMember(
      id: 'fake-daughter',
      name: 'Malika',
      relation: 'qizi',
      birthYear: DateTime.now().year - 5,
      bloodType: 'A(II) Rh+',
    ),
  ];
}

/// Fake-mode profile, persisted in SharedPreferences.
/// Default (nothing stored) is the complete «Aziz, 29» — so tests and
/// teammates' fake sessions skip the questionnaire. Onboarding calls
/// [startEmpty] on a fresh sign-in to show the questionnaire offline too.
class FakeProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(PrefKeys.fakeProfile);
    if (raw == null) return UserProfile.fake;
    try {
      return UserProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return UserProfile.fake;
    }
  }

  Future<void> save(UserProfile profile) async {
    state = profile;
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.fakeProfile, jsonEncode(profile.toMap()));
  }

  Future<void> startEmpty({String lang = 'uz'}) =>
      save(UserProfile(id: UserProfile.fake.id, fullName: '', lang: lang));
}

final fakeProfileProvider = NotifierProvider<FakeProfileNotifier, UserProfile>(
  FakeProfileNotifier.new,
);

/// Writes the current user's row in `profiles`.
abstract class ProfileRepository {
  Future<void> save(UserProfile profile);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client, {required this.onSaved});

  final SupabaseClient _client;
  final void Function() onSaved;

  @override
  Future<void> save(UserProfile profile) async {
    // upsert: the row normally exists (DB trigger), but be safe.
    await _client.from('profiles').upsert({
      ...profile.toMap(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    onSaved();
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this._notifier);

  final FakeProfileNotifier _notifier;

  @override
  Future<void> save(UserProfile profile) => _notifier.save(profile);
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeProfileRepository(ref.read(fakeProfileProvider.notifier))
      : SupabaseProfileRepository(
          ref.watch(supabaseClientProvider),
          onSaved: () => ref.invalidate(currentUserProvider),
        ),
);

/// Current user's profile (row in `profiles`). Fake: [fakeProfileProvider].
final currentUserProvider = FutureProvider<UserProfile?>((ref) async {
  if (ref.watch(useFakeProvider)) return ref.watch(fakeProfileProvider);
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;
  final row = await client
      .from('profiles')
      .select()
      .eq('id', uid)
      .maybeSingle();
  return row == null ? null : UserProfile.fromMap(row);
});

/// Where the router should keep a signed-in user.
enum ProfileGate {
  /// Profile is (re)loading — don't redirect.
  loading,

  /// Empty profile → `AppRoutes.profileSetup`.
  needsSetup,

  /// Profile filled (or failed to load — screens show the error).
  ready,
}

final profileGateProvider = Provider<ProfileGate>((ref) {
  if (!ref.watch(isSignedInProvider)) return ProfileGate.ready;
  final user = ref.watch(currentUserProvider);
  if (user.isLoading) return ProfileGate.loading;
  if (user.hasError) return ProfileGate.ready;
  final profile = user.value;
  return profile == null || !profile.isComplete
      ? ProfileGate.needsSetup
      : ProfileGate.ready;
});

/// Fake-mode family, persisted in SharedPreferences.
/// Default (nothing stored): Dilfuza, Akbar, Malika.
class FakeFamilyNotifier extends Notifier<List<FamilyMember>> {
  @override
  List<FamilyMember> build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(PrefKeys.fakeFamily);
    if (raw == null) return FamilyMember.fakes;
    try {
      return [
        for (final m in jsonDecode(raw) as List)
          FamilyMember.fromMap(Map<String, dynamic>.from(m as Map)),
      ];
    } catch (_) {
      return FamilyMember.fakes;
    }
  }

  Future<void> _save(List<FamilyMember> list) async {
    state = list;
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          PrefKeys.fakeFamily,
          jsonEncode([
            for (final m in list) {'id': m.id, ...m.toMap()},
          ]),
        );
  }

  /// Adds [member] with a new id; returns the stored member.
  Future<FamilyMember> add(FamilyMember member) async {
    final stored = FamilyMember.fromMap({
      ...member.toMap(),
      'id': 'fake-${DateTime.now().microsecondsSinceEpoch}',
    });
    await _save([...state, stored]);
    return stored;
  }

  Future<void> update(FamilyMember member) =>
      _save([for (final m in state) m.id == member.id ? member : m]);

  Future<void> remove(String id) => _save([
    for (final m in state)
      if (m.id != id) m,
  ]);
}

final fakeFamilyProvider =
    NotifierProvider<FakeFamilyNotifier, List<FamilyMember>>(
      FakeFamilyNotifier.new,
    );

/// Family members (`family_members`). Fake: [fakeFamilyProvider].
/// Changes go through the profile feature's `FamilyRepository`.
final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  if (ref.watch(useFakeProvider)) return ref.watch(fakeFamilyProvider);
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const [];
  final rows = await client
      .from('family_members')
      .select()
      .eq('user_id', uid)
      .order('created_at');
  return [for (final r in rows) FamilyMember.fromMap(r)];
});
