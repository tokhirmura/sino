import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../data/food_vision.dart';
import '../data/models.dart';
import 'labels.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/add_food_parts.dart';

/// Lightest / heaviest portion on the slider, grams.
const _minGrams = 20.0;
const _maxGrams = 1500.0;

/// «Rasmdan» (beta): take or pick a photo → AI (or a demo offline) offers
/// up to 3 dishes → pick one, correct the grams → added. Pops a
/// [FoodChoice].
class PhotoFoodScreen extends ConsumerStatefulWidget {
  const PhotoFoodScreen({super.key, required this.meal});

  final Meal meal;

  @override
  ConsumerState<PhotoFoodScreen> createState() => _PhotoFoodScreenState();
}

class _PhotoFoodScreenState extends ConsumerState<PhotoFoodScreen> {
  Uint8List? _photo;
  AsyncValue<VisionResult>? _result;
  int _selected = 0;
  double _grams = 300;

  Future<void> _pick(FoodPhotoSource source) async {
    Uint8List? bytes;
    try {
      bytes = await ref.read(foodPhotoPickerProvider).pick(source);
    } catch (e) {
      if (mounted) showNutritionSnack(context, errorMessage(context, e));
      return;
    }
    if (bytes == null || !mounted) return;
    setState(() => _photo = bytes);
    await _recognize();
  }

  Future<void> _recognize() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() => _result = const AsyncLoading());
    final lang = context.lang.name;
    try {
      final r = await ref
          .read(foodVisionRepositoryProvider)
          .recognize(photo, lang: lang);
      if (!mounted) return;
      setState(() {
        _result = AsyncData(r);
        _selected = 0;
        if (r.guesses.isNotEmpty) _grams = _snap(r.guesses.first.grams);
      });
    } catch (e, st) {
      if (mounted) setState(() => _result = AsyncError(e, st));
    }
  }

  static double _snap(double g) =>
      ((g / 10).round() * 10).clamp(_minGrams, _maxGrams).toDouble();

  void _reset() => setState(() {
    _photo = null;
    _result = null;
  });

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final result = _result;
    return AppScaffold(
      title: context.tr(
        uz: 'Rasmdan aniqlash',
        ru: 'Еда по фото',
        en: 'Food from a photo',
      ),
      subtitle: '${widget.meal.emoji} ${widget.meal.label(context)} · beta',
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 32),
        children: [
          if (photo == null)
            _Intro(onPick: _pick)
          else ...[
            _PhotoPreview(photo: photo, scanning: result?.isLoading ?? false),
            const SizedBox(height: AppSpacing.cardGap),
            if (result != null)
              result.when(
                loading: () => _Scanning(),
                error: (e, _) => ErrorView(error: e, onRetry: _recognize),
                data: (r) => r.guesses.isEmpty
                    ? EmptyState(
                        key: const Key('nutrition-photo-nothing'),
                        emoji: '🤔',
                        title: context.tr(
                          uz: 'Rasmda taom topilmadi',
                          ru: 'На фото не нашли еду',
                          en: 'No food found on the photo',
                        ),
                        message: context.tr(
                          uz: 'Likopchani yaqinroqdan, yorug‘da suratga oling.',
                          ru: 'Снимите тарелку ближе и при хорошем свете.',
                          en: 'Take the plate closer, in good light.',
                        ),
                        actionLabel: context.tr(
                          uz: 'Boshqa rasm',
                          ru: 'Другое фото',
                          en: 'Another photo',
                        ),
                        actionIcon: Icons.photo_camera_rounded,
                        onAction: _reset,
                      )
                    : _Result(
                        result: r,
                        selected: _selected,
                        grams: _grams,
                        onSelect: (i) => setState(() {
                          _selected = i;
                          _grams = _snap(r.guesses[i].grams);
                        }),
                        onGrams: (g) => setState(() => _grams = g),
                        onAdd: () => Navigator.of(context).pop(
                          FoodChoice(
                            r.guesses[_selected].toFood(_grams),
                            widget.meal,
                            1,
                          ),
                        ),
                        onRetake: _reset,
                      ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.tr(
              uz:
                  'Rasm bo‘yicha taxmin — xato bo‘lishi mumkin. Rasm saqlanmaydi. '
                  'Shifokor maslahatini almashtirmaydi.',
              ru:
                  'Оценка по фото может ошибаться. Фото не сохраняется. '
                  'Не заменяет консультацию врача.',
              en:
                  'A photo estimate can be wrong. The photo is not stored. '
                  'Does not replace a doctor’s advice.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onPick});

  final ValueChanged<FoodPhotoSource> onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        children: [
          const EmojiBox(emoji: '📸', color: AppColors.violet, size: 72),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(
              uz: 'Likopchani suratga oling',
              ru: 'Сфотографируйте тарелку',
              en: 'Take a photo of your plate',
            ),
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.tr(
              uz:
                  'Sun’iy intellekt taomni aniqlaydi, vaznini va kaloriyasini '
                  'taxmin qiladi. Siz faqat tasdiqlaysiz.',
              ru:
                  'ИИ узнает блюдо, оценит вес и калории. Вам останется '
                  'только подтвердить.',
              en:
                  'AI recognizes the dish and estimates its weight and '
                  'calories. You just confirm.',
            ),
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: const Key('nutrition-photo-camera'),
            label: context.tr(
              uz: 'Suratga olish',
              ru: 'Сделать фото',
              en: 'Take a photo',
            ),
            icon: Icons.photo_camera_rounded,
            onPressed: () => onPick(FoodPhotoSource.camera),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('nutrition-photo-gallery'),
              onPressed: () => onPick(FoodPhotoSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(
                context.tr(
                  uz: 'Galereyadan tanlash',
                  ru: 'Выбрать из галереи',
                  en: 'Pick from gallery',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The photo; while [scanning], a light line runs over it.
class _PhotoPreview extends StatefulWidget {
  const _PhotoPreview({required this.photo, required this.scanning});

  final Uint8List photo;
  final bool scanning;

  @override
  State<_PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends State<_PhotoPreview>
    with SingleTickerProviderStateMixin {
  late final _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_PhotoPreview old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.scanning && !_scan.isAnimating) {
      _scan.repeat(reverse: true);
    } else if (!widget.scanning && _scan.isAnimating) {
      _scan.stop();
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const height = 220.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              widget.photo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: AppColors.ink,
                child: Center(
                  child: Text('🍽️', style: TextStyle(fontSize: 48)),
                ),
              ),
            ),
            if (widget.scanning) ...[
              ColoredBox(color: AppColors.ink.withValues(alpha: 0.25)),
              AnimatedBuilder(
                animation: _scan,
                builder: (_, _) => Positioned(
                  left: 0,
                  right: 0,
                  top: (height - 4) * _scan.value,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AppColors.brand(Brightness.light),
                      boxShadow: AppShadows.glow(AppColors.primary),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Scanning extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    key: const Key('nutrition-photo-scanning'),
    children: [
      Text(
        context.tr(
          uz: 'Taom aniqlanmoqda…',
          ru: 'Узнаём блюдо…',
          en: 'Recognizing the dish…',
        ),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.sm),
      const SkeletonLoader(count: 3, kind: SkeletonKind.list),
    ],
  );
}

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    required this.selected,
    required this.grams,
    required this.onSelect,
    required this.onGrams,
    required this.onAdd,
    required this.onRetake,
  });

  final VisionResult result;
  final int selected;
  final double grams;
  final ValueChanged<int> onSelect;
  final ValueChanged<double> onGrams;
  final VoidCallback onAdd;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final food = result.guesses[selected].toFood(grams);
    final g = gramUnit(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.demo) ...[
          Pill(
            context.tr(
              uz: 'Demo-taxmin: sun’iy intellekt hozir ulanmagan',
              ru: 'Демо-оценка: ИИ сейчас недоступен',
              en: 'Demo guess: AI is not connected right now',
            ),
            color: AppColors.saffron,
            icon: Icons.info_outline_rounded,
            wrap: true,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          context.tr(
            uz: 'Bu qaysi taom?',
            ru: 'Что это за блюдо?',
            en: 'Which dish is it?',
          ),
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < result.guesses.length; i++) ...[
          ChoiceTile(
            key: Key('nutrition-photo-guess-$i'),
            emoji: result.guesses[i].emoji,
            color: AppColors.violet,
            title: context.trMap(result.guesses[i].name),
            subtitle:
                '~${result.guesses[i].grams.round()} $g · '
                '${result.guesses[i].kcal.round()} ${kcalUnit(context)}',
            trailing: '${(result.guesses[i].confidence * 100).round()}%',
            selected: i == selected,
            onTap: () => onSelect(i),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr(
                        uz: 'Qancha yedingiz?',
                        ru: 'Сколько съели?',
                        en: 'How much did you eat?',
                      ),
                      style: text.titleSmall,
                    ),
                  ),
                  Text(
                    '${grams.round()} $g',
                    key: const Key('nutrition-photo-grams'),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Slider(
                value: grams,
                min: _minGrams,
                max: _maxGrams,
                divisions: ((_maxGrams - _minGrams) / 10).round(),
                label: '${grams.round()} $g',
                onChanged: onGrams,
              ),
              NutrientLine(food: food),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        PrimaryButton(
          key: const Key('nutrition-photo-add'),
          label: context.tr(
            uz: 'Qo‘shish · ${food.kcal.round()} kkal',
            ru: 'Добавить · ${food.kcal.round()} ккал',
            en: 'Add · ${food.kcal.round()} kcal',
          ),
          icon: Icons.add_rounded,
          onPressed: onAdd,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          onPressed: onRetake,
          icon: const Icon(Icons.photo_camera_rounded),
          label: Text(
            context.tr(
              uz: 'Boshqa rasm',
              ru: 'Другое фото',
              en: 'Another photo',
            ),
          ),
        ),
      ],
    );
  }
}
