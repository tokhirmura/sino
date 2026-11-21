import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../application/breathing.dart';

/// Path of the breathing exercise (a sub-route of `/vitals`).
const vitalsBreathingPath = '${AppRoutes.vitals}/breathing';

/// Night version of the brand gradient, top → bottom.
final _bg = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: AppColors.brandGradientDark.colors,
);
const _glow = AppColors.primary;
const _onWhite = AppColors.secondary;

/// Light core of the circle → turquoise rim.
final _core = RadialGradient(
  colors: [
    Color.lerp(Colors.white, AppColors.primary, 0.45)!,
    AppColors.primary,
  ],
);

/// 4-7-8 breathing: the circle grows for 4 s (inhale), stays for 7 s
/// (hold), shrinks for 8 s (exhale); 4–8 cycles.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

enum _Stage { setup, running, done }

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  _Stage _stage = _Stage.setup;
  int _cycles = breathCycleOptions.first;

  /// Time before the current run of the ticker (pauses).
  Duration _base = Duration.zero;
  Duration _elapsed = Duration.zero;
  bool _paused = false;
  BreathState _state = breathStateAt(Duration.zero, breathCycleOptions.first);

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration d) {
    final next = breathStateAt(_base + d, _cycles);
    if (next.phase != _state.phase || next.cycle != _state.cycle) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _elapsed = _base + d;
      _state = next;
      if (next.done) {
        _ticker.stop();
        _stage = _Stage.done;
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _start() {
    setState(() {
      _base = Duration.zero;
      _elapsed = Duration.zero;
      _paused = false;
      _state = breathStateAt(Duration.zero, _cycles);
      _stage = _Stage.running;
    });
    _ticker
      ..stop()
      ..start();
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _base = _elapsed;
        _ticker.stop();
      } else {
        _ticker.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        // The theme fixes the title colour — white on the dark gradient.
        title: Text(
          context.tr(
            uz: '4-7-8 nafas mashqi',
            ru: 'Дыхание 4-7-8',
            en: '4-7-8 breathing',
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: _bg),
        child: SafeArea(
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: switch (_stage) {
                    _Stage.setup => _setup(context, text, c),
                    _Stage.running => _running(context, text, c),
                    _Stage.done => _done(context, text),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fits the screen: at most 38 % of the height, so «Start» and the
  /// buttons stay visible on small phones.
  double _circleSize(BoxConstraints c) => [
    c.maxWidth - 48,
    c.maxHeight * 0.38,
    300.0,
  ].reduce((a, b) => a < b ? a : b).clamp(150.0, 300.0);

  Widget _setup(BuildContext context, TextTheme text, BoxConstraints c) {
    final white = text.bodyLarge?.copyWith(color: Colors.white);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        // Smaller than in the exercise: «Start» must fit on a small phone.
        _Circle(
          size: _circleSize(c) * 0.75,
          scale: 0.8,
          child: const Text('🌬️', style: TextStyle(fontSize: 48)),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr(
            uz: 'Tinchlanish va uyquga yordam beradi',
            ru: 'Помогает успокоиться и уснуть',
            en: 'Helps you calm down and fall asleep',
          ),
          style: text.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr(uz: 'Sikllar soni', ru: 'Циклов', en: 'Cycles'),
          style: text.labelLarge?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          children: [
            for (final n in breathCycleOptions)
              ChoiceChip(
                key: Key('breath-cycles-$n'),
                label: Text('$n · ${_durationText(context, breathTotal(n))}'),
                selected: _cycles == n,
                onSelected: (_) => setState(() => _cycles = n),
              ),
          ],
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          key: const Key('breath-start'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _onWhite,
            minimumSize: const Size(200, 52),
          ),
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(context.tr(uz: 'Boshlash', ru: 'Начать', en: 'Start')),
        ),
        const SizedBox(height: 20),
        Text(
          context.tr(
            uz:
                '4 soniya burun orqali nafas oling, 7 soniya ushlab turing, '
                '8 soniya og‘iz orqali to‘liq chiqaring.',
            ru:
                'Вдох носом 4 секунды, задержка 7 секунд, полный выдох ртом '
                '8 секунд.',
            en:
                'Breathe in through the nose for 4 s, hold for 7 s, breathe '
                'out fully through the mouth for 8 s.',
          ),
          style: white,
        ),
        const SizedBox(height: 16),
        _Disclaimer(text: text),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _running(BuildContext context, TextTheme text, BoxConstraints c) {
    final s = _state;
    final (word, hint) = switch (s.phase) {
      BreathPhase.inhale => (
        context.tr(uz: 'Nafas oling', ru: 'Вдох', en: 'Breathe in'),
        context.tr(
          uz: 'Burun orqali, jimgina',
          ru: 'Носом, спокойно',
          en: 'Through the nose, quietly',
        ),
      ),
      BreathPhase.hold => (
        context.tr(uz: 'Ushlab turing', ru: 'Задержка', en: 'Hold'),
        context.tr(
          uz: 'Yelkalarni bo‘shating',
          ru: 'Расслабьте плечи',
          en: 'Relax your shoulders',
        ),
      ),
      BreathPhase.exhale => (
        context.tr(uz: 'Nafas chiqaring', ru: 'Выдох', en: 'Breathe out'),
        context.tr(
          uz: 'Og‘iz orqali, «vush» ovozi bilan',
          ru: 'Ртом, со звуком «ффф»',
          en: 'Through the mouth, with a “whoosh”',
        ),
      ),
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Text(
          context.tr(
            uz: '${s.cycle}-sikl / $_cycles',
            ru: 'Цикл ${s.cycle} из $_cycles',
            en: 'Cycle ${s.cycle} of $_cycles',
          ),
          key: const Key('breath-cycle'),
          style: text.labelLarge?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        _CycleDots(total: _cycles, current: s.cycle),
        const SizedBox(height: 24),
        _Circle(
          key: const Key('breath-circle'),
          size: _circleSize(c),
          scale: s.scale,
          holding: s.phase == BreathPhase.hold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${s.secondsLeft}',
                key: const Key('breath-count'),
                style: text.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            word,
            key: const Key('breath-phase'),
            style: text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(hint, style: text.bodyMedium?.copyWith(color: Colors.white70)),
        const SizedBox(height: 28),
        // The theme makes buttons full-width — Expanded keeps them in a row.
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('breath-pause'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                onPressed: _togglePause,
                icon: Icon(
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(
                  _paused
                      ? context.tr(
                          uz: 'Davom etish',
                          ru: 'Продолжить',
                          en: 'Resume',
                        )
                      : context.tr(uz: 'Pauza', ru: 'Пауза', en: 'Pause'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                key: const Key('breath-stop'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                onPressed: () {
                  _ticker.stop();
                  setState(() => _stage = _Stage.setup);
                },
                child: Text(
                  context.tr(uz: 'To‘xtatish', ru: 'Стоп', en: 'Stop'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _done(BuildContext context, TextTheme text) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('🌿', style: TextStyle(fontSize: 72)),
      const SizedBox(height: 12),
      Text(
        context.tr(uz: 'Barakalla!', ru: 'Отлично!', en: 'Well done!'),
        key: const Key('breath-done'),
        style: text.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        context.tr(
          uz: '$_cycles sikl · ${_durationText(context, breathTotal(_cycles))}',
          ru: '$_cycles цикл. · ${_durationText(context, breathTotal(_cycles))}',
          en: '$_cycles cycles · ${_durationText(context, breathTotal(_cycles))}',
        ),
        key: const Key('breath-summary'),
        style: text.titleMedium?.copyWith(color: Colors.white),
      ),
      const SizedBox(height: 16),
      Text(
        context.tr(
          uz:
              'Kuniga 2 marta takrorlang. Dastlabki oyda 4 sikldan '
              'oshirmagan ma’qul.',
          ru:
              'Повторяйте 2 раза в день. В первый месяц лучше не больше '
              '4 циклов.',
          en:
              'Repeat twice a day. In the first month, keep it to 4 '
              'cycles.',
        ),
        style: text.bodyMedium?.copyWith(color: Colors.white70),
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        key: const Key('breath-again'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _onWhite,
          minimumSize: const Size(200, 52),
        ),
        onPressed: _start,
        icon: const Icon(Icons.replay_rounded),
        label: Text(context.tr(uz: 'Yana bir bor', ru: 'Ещё раз', en: 'Again')),
      ),
      const SizedBox(height: 8),
      TextButton(
        key: const Key('breath-close'),
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(context.tr(uz: 'Yopish', ru: 'Закрыть', en: 'Close')),
      ),
      const SizedBox(height: 24),
      _Disclaimer(text: text),
    ],
  );

  static String _durationText(BuildContext context, Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    return context.tr(
      uz: s == 0 ? '$m daq' : '$m daq $s s',
      ru: s == 0 ? '$m мин' : '$m мин $s с',
      en: s == 0 ? '$m min' : '$m min $s s',
    );
  }
}

/// The breathing circle: soft glow rings + a gradient disc, scaled.
class _Circle extends StatelessWidget {
  const _Circle({
    super.key,
    required this.size,
    required this.scale,
    required this.child,
    this.holding = false,
  });

  final double size;
  final double scale;
  final Widget child;
  final bool holding;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final (k, a) in [(1.0, 0.08), (0.88, 0.12), (0.76, 0.18)])
            Transform.scale(
              scale: scale * k,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _glow.withValues(alpha: a),
                ),
              ),
            ),
          Transform.scale(
            scale: scale * 0.64,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _core,
                boxShadow: [
                  BoxShadow(
                    color: _glow.withValues(alpha: holding ? 0.7 : 0.4),
                    blurRadius: holding ? 48 : 28,
                    spreadRadius: holding ? 6 : 2,
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _CycleDots extends StatelessWidget {
  const _CycleDots({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 1; i <= total; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == current ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i <= current ? Colors.white : Colors.white30,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ],
  );
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.text});

  final TextTheme text;

  @override
  Widget build(BuildContext context) => Text(
    context.tr(
      uz:
          'Bosh aylansa, to‘xtating va odatdagidek nafas oling. '
          'Shifokor maslahatini almashtirmaydi.',
      ru:
          'Если закружится голова — остановитесь и дышите как обычно. '
          'Не заменяет консультацию врача.',
      en:
          'If you feel dizzy, stop and breathe normally. '
          'Does not replace a doctor’s advice.',
    ),
    style: text.bodySmall?.copyWith(color: Colors.white60),
  );
}
