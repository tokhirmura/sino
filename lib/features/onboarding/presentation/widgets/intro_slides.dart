import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/emoji_box.dart';
import 'common.dart';

class _Slide {
  const _Slide(this.emoji, this.color, this.title, this.body);
  final String emoji;
  final Color color;
  final String title;
  final String body;
}

/// Three slides about the app → [onDone].
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
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides(context);
    final text = Theme.of(context).textTheme;
    final isLast = _page == slides.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              const LangSwitcher(),
              const SizedBox(width: 8),
              if (!isLast)
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
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
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final s in slides)
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EmojiBox(emoji: s.emoji, color: s.color, size: 120),
                          const SizedBox(height: 32),
                          Text(
                            s.title,
                            textAlign: TextAlign.center,
                            style: text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.body,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _next(slides.length),
            child: Text(
              isLast
                  ? context.tr(uz: 'Boshlash', ru: 'Начать', en: 'Get started')
                  : context.tr(uz: 'Keyingi', ru: 'Далее', en: 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}
