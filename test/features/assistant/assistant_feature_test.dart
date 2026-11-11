import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sino/core/routing/app_routes.dart';
import 'package:sino/features/assistant/assistant_feature.dart';
import 'package:sino/features/assistant/presentation/assistant_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  test('assistant exposes its root route', () {
    final paths = [
      for (final r in assistantRoutes.whereType<GoRoute>()) r.path,
    ];
    expect(paths, contains(AppRoutes.assistant));
  });

  testWidgets('assistant screen renders stub (fake mode)', (tester) async {
    await pumpScreen(tester, const AssistantScreen());
    expect(find.text('Yordamchi — tez orada'), findsOneWidget);
  });
}
