import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sino/core/l10n/app_lang.dart';
import 'package:sino/core/theme/app_colors.dart';
import 'package:sino/core/theme/app_theme.dart';
import 'package:sino/core/widgets/widgets.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  bool scaffold = false,
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: AppLang.uz.locale,
      supportedLocales: AppLang.locales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: scaffold
          ? child
          : Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Code points covered by a TrueType font (cmap formats 4 and 12).
Set<int> _cmap(ByteData d) {
  final tables = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final rec = 12 + 16 * i;
    final tag = String.fromCharCodes([
      for (var k = 0; k < 4; k++) d.getUint8(rec + k),
    ]);
    if (tag == 'cmap') cmap = d.getUint32(rec + 8);
  }
  final out = <int>{};
  final n = d.getUint16(cmap + 2);
  for (var i = 0; i < n; i++) {
    final sub = cmap + d.getUint32(cmap + 4 + 8 * i + 4);
    switch (d.getUint16(sub)) {
      case 4:
        final segX2 = d.getUint16(sub + 6);
        for (var s = 0; s < segX2 ~/ 2; s++) {
          final end = d.getUint16(sub + 14 + 2 * s);
          final start = d.getUint16(sub + 16 + segX2 + 2 * s);
          for (var c = start; c <= end; c++) {
            out.add(c);
          }
        }
      case 12:
        final groups = d.getUint32(sub + 12);
        for (var g = 0; g < groups; g++) {
          final start = d.getUint32(sub + 16 + 12 * g);
          final end = d.getUint32(sub + 20 + 12 * g);
          for (var c = start; c <= end; c++) {
            out.add(c);
          }
        }
    }
  }
  return out;
}

void main() {
  test('theme uses the bundled Inter font', () {
    for (final t in [AppTheme.light, AppTheme.dark]) {
      expect(t.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
      expect(t.textTheme.headlineMedium?.fontFamily, AppTheme.fontFamily);
    }
  });

  test('palette «Samarqand»', () {
    expect(AppColors.primary, const Color(0xFF0FB5AE));
    expect(AppColors.secondary, const Color(0xFF1D4ED8));
    expect(AppColors.saffron, const Color(0xFFF5A524));
    expect(AppColors.danger, const Color(0xFFE11D48));
    expect(AppColors.background, const Color(0xFFFAF7F2));
    expect(AppColors.backgroundDark, const Color(0xFF0B1220));
    expect(AppColors.cardRadius, 24);
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.background);
    expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.backgroundDark);
  });

  testWidgets('bundled Inter covers Uzbek ʻ (U+02BB) and Cyrillic', (
    tester,
  ) async {
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final data = await rootBundle.load('assets/fonts/Inter-$w.ttf');
      final cps = _cmap(data);
      for (final c in [
        0x02BB, // ʻ in oʻ, gʻ
        0x2018, 0x2019, // ‘ ’ as typed in the app
        0x040E, 0x045E, 0x049A, 0x049B, 0x0492, 0x0493, 0x04B2, 0x04B3,
        for (var k = 0x0410; k <= 0x044F; k++) k,
      ]) {
        expect(
          cps,
          contains(c),
          reason: 'Inter-$w lacks U+${c.toRadixString(16)}',
        );
      }
    }
  });

  test('readable() keeps brand colors legible as text', () {
    double contrast(Color a, Color b) {
      final l1 = a.computeLuminance(), l2 = b.computeLuminance();
      return ((l1 > l2 ? l1 : l2) + 0.05) / ((l1 > l2 ? l2 : l1) + 0.05);
    }

    for (final c in [
      AppColors.primary,
      AppColors.saffron,
      AppColors.sky,
      AppColors.good,
      AppColors.coral,
    ]) {
      expect(
        contrast(AppColors.readable(c, Brightness.light), Colors.white),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(AppColors.readable(c, Brightness.dark), AppColors.surfaceDark),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  for (final entry in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    testWidgets('new widgets render at 360 px (${entry.key})', (tester) async {
      await _pump(
        tester,
        theme: entry.value,
        Column(
          children: [
            const GradientHeader(
              title: 'Salom, Aziz',
              subtitle: 'Shanba, 21-noyabr',
              safeTop: false,
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: '8 432',
                      label: 'Qadam',
                      emoji: '👣',
                      onDark: true,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      value: '6/8',
                      label: 'Suv',
                      emoji: '💧',
                      onDark: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '1 520',
                    unit: 'kkal',
                    label: 'Bugun',
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.saffron,
                    caption: '580 kkal qoldi',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: StatTile(value: '72', unit: 'zarba', label: 'Puls'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const AnimatedProgressRing(value: 0.72),
            const Wrap(
              children: [
                AchievementBadge(emoji: '🔥', title: '7 kun ketma-ket'),
                AchievementBadge(
                  emoji: '🏆',
                  title: 'Birinchi mashg‘ulot',
                  unlocked: false,
                ),
              ],
            ),
            PrimaryButton(label: 'Boshlash', onPressed: () {}),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Salom, Aziz'), findsOneWidget);
      expect(find.text('8 432'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });
  }

  testWidgets('PrimaryButton: tap, disabled and loading', (tester) async {
    var taps = 0;
    Widget build({bool loading = false, bool enabled = true}) => PrimaryButton(
      label: 'Saqlash',
      icon: Icons.check_rounded,
      loading: loading,
      onPressed: enabled ? () => taps++ : null,
    );

    await _pump(tester, build());
    await tester.tap(find.text('Saqlash'));
    expect(taps, 1);

    await _pump(tester, build(enabled: false));
    await tester.tap(find.text('Saqlash'), warnIfMissed: false);
    expect(taps, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: build(loading: true)),
      ),
    );
    await tester.pump();
    expect(find.text('Saqlash'), findsNothing);
    await tester.tap(find.byType(PrimaryButton));
    expect(taps, 1);
  });

  testWidgets('EmptyState actionLabel → gradient button', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      scaffold: true,
      Scaffold(
        body: EmptyState(
          emoji: '💊',
          title: 'Eslatmalar yo‘q',
          message: 'Dori vaqtini qo‘shing',
          actionLabel: 'Qo‘shish',
          onAction: () => tapped = true,
        ),
      ),
    );
    expect(find.byType(PrimaryButton), findsOneWidget);
    await tester.tap(find.text('Qo‘shish'));
    expect(tapped, isTrue);
  });

  testWidgets('AppScaffold: gradient header, white actions, subtitle', (
    tester,
  ) async {
    await _pump(
      tester,
      scaffold: true,
      AppScaffold(
        title: 'Dorixona',
        subtitle: 'Toshkent',
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.map_outlined)),
        ],
        body: const AppCard(child: Text('Paracetamol')),
      ),
    );
    expect(find.byType(GradientBackdrop), findsOneWidget);
    expect(find.byType(GirihPattern), findsOneWidget);
    expect(find.text('Toshkent'), findsOneWidget);
    final icon = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.map_outlined),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(icon.data.color, Colors.white);
  });

  testWidgets('cards cascade in and end fully visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              for (var i = 0; i < 4; i++) AppCard(child: Text('card $i')),
            ],
          ),
        ),
      ),
    );
    double opacityOf(int i) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.text('card $i'),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(opacityOf(0), lessThan(1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opacityOf(0), greaterThan(opacityOf(3)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      expect(opacityOf(i), 1);
    }
  });

  testWidgets('LoadingView fits small and unbounded spaces', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 80, child: LoadingView()),
                SizedBox(
                  height: 300,
                  child: LoadingView(message: 'Yuklanmoqda'),
                ),
                LoadingView(),
                LoadingView(compact: true),
                SkeletonLoader(count: 3, kind: SkeletonKind.grid),
                SkeletonLoader(count: 1, kind: SkeletonKind.card),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('Yuklanmoqda'), findsOneWidget);
    expect(find.byType(Skeleton), findsWidgets);
  });
}
