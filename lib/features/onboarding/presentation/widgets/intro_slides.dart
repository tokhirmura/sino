import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../../core/widgets/primary_button.dart';
import 'common.dart';

class _Slide {
  const _Slide(this.emoji, this.color, this.title, this.body);
  final String emoji;

  /// Start of the slide's gradient (ends in lapis).
  final Color color;
  final String title;
  final String body;
}

/// Three slides about the app → [onDone].
///
/// Design 2.0: each slide is a gradient «sky» with the girih ornament and
/// a glowing glass circle with the emoji, the text below; language switch
/// and «O‘tkazib yuborish» float over the gradient. Fills the screen edge
/// to edge (the parent leaves the top unpadded).
class IntroSlides extends StatefulWidget {
  const IntroSlides({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroSlides> createState() => _IntroSlidesState();
}

class _IntroSlidesState extends State<IntroSlides> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Slide> _slides(BuildContext context) => [
    _Slide(
      '🌿',
      AppColors.primary,
      context.tr(
        uz: 'Sog‘lig‘ingiz — bitta ilovada',
        ru: 'Ваше здоровье — в одном приложении',
        en: 'Your health in one app',
      ),
      context.tr(
        uz:
            'Dorixonalar, ovqatlanish, mashg‘ulotlar, shifokorlar va '
            'tibbiy karta — barchasi Sino’da.',
        ru: 'Аптеки, питание, тренировки, врачи и медкарта — всё в Sino.',
        en:
            'Pharmacies, nutrition, workouts, doctors and your medical '
            'record — all in Sino.',
      ),
    ),
    _Slide(
      '💊',
      AppColors.sky,
      context.tr(
        uz: 'Dorini tez toping',
        ru: 'Быстро найдите лекарство',
        en: 'Find medicine fast',
      ),
      context.tr(
        uz:
            'Yaqin dorixonalarda narx va mavjudlikni solishtiring, bron '
            'qiling va dori ichishni eslatib qo‘ying.',
        ru:
            'Сравните цены и наличие в ближайших аптеках, забронируйте и '
            'поставьте напоминание о приёме.',
        en:
            'Compare prices and stock in nearby pharmacies, reserve and set '
            'dose reminders.',
      ),
    ),
    _Slide(
      '🩺',
      AppColors.violet,
      context.tr(
        uz: 'Tibbiy kartangiz doim yoningizda',
        ru: 'Медкарта всегда с вами',
        en: 'Your medical record, always with you',
      ),
      context.tr(
        uz:
            'OneID orqali kiring — poliklinika, retseptlar va tahlillar '
            'avtomatik yuklanadi.',
        ru:
            'Войдите через OneID — поликлиника, рецепты и анализы '
            'подтянутся автоматически.',
        en:
            'Sign in with OneID — your polyclinic, prescriptions and lab '
            'results load automatically.',
      ),
    ),
  ];

  void _next(int count) {
    if (_page == count - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(duration: AppMotion.medium, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides(context);
    final theme = Theme.of(context);
    final isLast = _page == slides.length - 1;
    final dot = AppColors.readable(AppColors.primary, theme.brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final (i, s) in slides.indexed)
                      _SlidePage(slide: s, active: i == _page),
                  ],
                ),
                // Language + skip float over the gradient.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(
                        children: [
                          const LangSwitcher(onDark: true),
                          const SizedBox(width: 8),
                          if (!isLast)
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: widget.onDone,
                                  child: Text(
                                    context.tr(
                                      uz: 'O‘tkazib yuborish',
                                      ru: 'Пропустить',
                                      en: 'Skip',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < slides.length; i++)
                      AnimatedContainer(
                        duration: AppMotion.medium,
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? dot : dot.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: isLast
                      ? context.tr(
                          uz: 'Boshlash',
                          ru: 'Начать',
                          en: 'Get started',
                        )
                      : context.tr(uz: 'Keyingi', ru: 'Далее', en: 'Next'),
                  icon: isLast
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: () => _next(slides.length),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide, required this.active});

  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      children: [
        Expanded(
          flex: 11,
          child: GradientBackdrop(
            bottomRadius: 40,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [slide.color, AppColors.secondary],
            ),
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Padding(
                  // Room for the language row above.
                  padding: const EdgeInsets.only(top: 48, bottom: 12),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final size = (c.maxHeight * 0.8).clamp(96.0, 184.0);
                      return AnimatedScale(
                        scale: active || reduceMotion ? 1 : 0.7,
                        duration: AppMotion.slow,
                        curve: AppMotion.spring,
                        child: _GlassCircle(emoji: slide.emoji, size: size),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
            child: Column(
              children: [
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Frosted circle with a soft white glow and the emoji.
class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.emoji, required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.38),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.22),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.02,
          ),
        ],
      ),
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.46, height: 1.1),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}
