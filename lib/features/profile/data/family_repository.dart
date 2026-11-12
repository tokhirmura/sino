import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';
import 'medical_repository.dart';

/// Add / change / delete the current user's family members.
/// Reads go through core `familyMembersProvider`.
abstract class FamilyRepository {
  /// [member]'s id is ignored — a new one is generated.
  Future<void> add(FamilyMember member);
  Future<void> update(FamilyMember member);

  /// Also deletes the member's medical records (FK `on delete cascade`).
  Future<void> remove(String id);
}

class SupabaseFamilyRepository implements FamilyRepository {
  SupabaseFamilyRepository(this._client, {required this.onChanged});

  final SupabaseClient _client;

  /// Invalidates the providers that read family / records.
  final void Function() onChanged;

  @override
  Future<void> add(FamilyMember member) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    await _client.from('family_members').insert({
      ...member.toMap(),
      'user_id': uid,
    });
    onChanged();
  }

  @override
  Future<void> update(FamilyMember member) async {
    await _client
        .from('family_members')
        .update(member.toMap())
        .eq('id', member.id);
    onChanged();
  }

  @override
  Future<void> remove(String id) async {
    await _client.from('family_members').delete().eq('id', id);
    onChanged();
  }
}

class FakeFamilyRepository implements FamilyRepository {
  FakeFamilyRepository(this._notifier);

  final FakeFamilyNotifier _notifier;

  @override
  Future<void> add(FamilyMember member) => _notifier.add(member);

  @override
  Future<void> update(FamilyMember member) => _notifier.update(member);

  @override
  Future<void> remove(String id) => _notifier.remove(id);
}

final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => ref.watch(useFakeProvider)
      ? FakeFamilyRepository(ref.read(fakeFamilyProvider.notifier))
      : SupabaseFamilyRepository(
          ref.watch(supabaseClientProvider),
          onChanged: () => ref
            ..invalidate(familyMembersProvider)
            ..invalidate(medicalRecordsProvider),
        ),
);
