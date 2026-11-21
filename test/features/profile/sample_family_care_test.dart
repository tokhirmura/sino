import 'package:flutter_test/flutter_test.dart';
import 'package:sino/features/profile/data/sample_data_repository.dart';

void main() {
  test('demo dose time: minutes ago, rounded to 5, stays today', () {
    expect(demoMinutes(DateTime(2026, 11, 21, 14), 95), 12 * 60 + 25);
    expect(demoMinutes(DateTime(2026, 11, 21, 14, 3), 0), 14 * 60);
    expect(demoMinutes(DateTime(2026, 11, 21, 1), 240), 5);
    expect(hhmmss(545), '09:05:00');
    expect(hhmmss(5), '00:05:00');
  });

  test('fake seeding reports the family demo too', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final r = await FakeSampleDataRepository().seed();
    expect(r.familyMembers, 3);
    expect(r.familyCare, 2);
  });
}
