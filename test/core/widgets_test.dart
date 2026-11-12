import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/core/widgets/app_card.dart';
import 'package:sino/core/widgets/async_value_view.dart';
import 'package:sino/core/widgets/empty_state.dart';
import 'package:sino/core/widgets/error_view.dart';
import 'package:sino/core/widgets/loading_view.dart';
import 'package:sino/core/widgets/pill.dart';
import 'package:sino/core/widgets/progress_ring.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  AppLang lang = AppLang.uz,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: lang.locale,
      supportedLocales: AppLang.locales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: child),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    testWidgets('core widgets render in ${entry.key} theme', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ShortcutCard(
              emoji: '💊',
              title: 'Dorixona',
              subtitle: 'Dori qidirish',
              onTap: () => taps++,
            ),
            const SizedBox(height: 12),
            const Pill('24/7'),
            const ProgressRing(value: 0.6, child: Text('60%')),
            const SizedBox(height: 300, child: EmptyState(title: 'Bo‘sh')),
          ],
        ),
        theme: entry.value,
      );
      await tester.tap(find.text('Dorixona'));
      expect(taps, 1);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('Bo‘sh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ShortcutCard without onTap has no chevron', (tester) async {
    await _pump(tester, const ShortcutCard(emoji: '👤', title: 'Aziz'));
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('ProgressRing animates to target value', (tester) async {
    await _pump(tester, const ProgressRing(value: 0.5), settle: false);
    final semantics = tester.getSemantics(find.byType(ProgressRing));
    expect(semantics.value, '50%');
    await tester.pumpAndSettle();
  });

  group('ErrorView', () {
    testWidgets('shows friendly text and retries', (tester) async {
      var retried = false;
      await _pump(
        tester,
        ErrorView(error: TimeoutException('x'), onRetry: () => retried = true),
      );
      expect(find.text('Xatolik yuz berdi'), findsOneWidget);
      expect(find.textContaining('Server javob bermadi'), findsOneWidget);
      await tester.tap(find.text('Qayta urinish'));
      expect(retried, isTrue);
    });

    testWidgets('network error in Russian, compact', (tester) async {
      await _pump(
        tester,
        ErrorView(
          error: Exception('SocketException: Failed host lookup'),
          compact: true,
          onRetry: () {},
        ),
        lang: AppLang.ru,
      );
      expect(find.textContaining('Нет подключения'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });

  group('AsyncValueView', () {
    testWidgets('loading → spinner', (tester) async {
      await _pump(
        tester,
        AsyncValueView<int>(
          value: const AsyncValue.loading(),
          data: (v) => Text('$v'),
        ),
        settle: false,
      );
      expect(find.byType(LoadingView), findsOneWidget);
    });

    testWidgets('data → builder', (tester) async {
      await _pump(
        tester,
        AsyncValueView<int>(
          value: const AsyncValue.data(42),
          data: (v) => Text('$v'),
        ),
      );
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('error → ErrorView', (tester) async {
      await _pump(
        tester,
        AsyncValueView<int>(
          value: AsyncValue.error(StateError('x'), StackTrace.empty),
          data: (v) => Text('$v'),
          onRetry: () {},
        ),
      );
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.textContaining('Nimadir noto‘g‘ri ketdi'), findsOneWidget);
    });
  });

  testWidgets('SkeletonList renders placeholders', (tester) async {
    await _pump(tester, const SkeletonList(count: 2), settle: false);
    expect(find.byType(Skeleton), findsNWidgets(2));
  });
}
