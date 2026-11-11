import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/backend.dart';

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
  });

  final String id;
  final String fullName;
  final int? birthYear;
  final double? heightCm;
  final double? weightKg;
  final String? bloodType;
  final List<String> allergies;
  final String lang;

  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    id: m['id'] as String,
    fullName: (m['full_name'] as String?) ?? '',
    birthYear: m['birth_year'] as int?,
    heightCm: (m['height_cm'] as num?)?.toDouble(),
    weightKg: (m['weight_kg'] as num?)?.toDouble(),
    bloodType: m['blood_type'] as String?,
    allergies: List<String>.from(m['allergies'] as List? ?? const []),
    lang: (m['lang'] as String?) ?? 'uz',
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

/// Current user's profile (row in `profiles`). Fake: «Aziz, 29».
final currentUserProvider = FutureProvider<UserProfile?>((ref) async {
  if (ref.watch(useFakeProvider)) return UserProfile.fake;
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

/// Family members (`family_members`). Fake: Dilfuza, Akbar, Malika.
final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  if (ref.watch(useFakeProvider)) return FamilyMember.fakes;
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
