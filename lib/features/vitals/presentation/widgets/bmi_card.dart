import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/vitals_math.dart';
import '../labels.dart';

/// BMI calculator: height and weight are prefilled (profile / the latest
/// weight measurement) and can be changed.
class BmiCard extends StatefulWidget {
  const BmiCard({super.key, this.heightCm, this.weightKg});

  final double? heightCm;
  final double? weightKg;

  @override
  State<BmiCard> createState() => _BmiCardState();
}

class _BmiCardState extends State<BmiCard> {
  late final _height = TextEditingController(text: _fmt(widget.heightCm));
  late final _weight = TextEditingController(text: _fmt(widget.weightKg));

  static String _fmt(double? v) {
    if (v == null) return '';
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  @override
  void didUpdateWidget(BmiCard old) {
    super.didUpdateWidget(old);
    // A new weight measurement arrived and the field was not edited.
    if (old.weightKg != widget.weightKg && _weight.text == _fmt(old.weightKg)) {
      _weight.text = _fmt(widget.weightKg);
    }
    if (old.heightCm != widget.heightCm && _height.text == _fmt(old.heightCm)) {
      _height.text = _fmt(widget.heightCm);
    }
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final h = _parse(_height.text);
    final w = _parse(_weight.text);
    final valid =
        h != null && w != null && h >= 100 && h <= 250 && w >= 20 && w <= 300;
    final value = valid ? bmi(weightKg: w, heightCm: h) : null;
    final level = value == null ? null : bmiLevel(value);
    final info = level == null ? null : bmiText(context, level);
    final color = info?.color ?? AppColors.good;

    InputDecoration deco(String label, String unit) => InputDecoration(
      labelText: label,
      suffixText: unit,
      isDense: true,
      border: const OutlineInputBorder(),
    );
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return AppCard(
      key: const Key('vitals-bmi'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(
              uz: 'Tana vazni indeksi (TVI / BMI)',
              ru: 'Индекс массы тела (ИМТ)',
              en: 'Body mass index (BMI)',
            ),
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('vitals-bmi-height'),
                  controller: _height,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: digits,
                  decoration: deco(
                    context.tr(uz: 'Bo‘y', ru: 'Рост', en: 'Height'),
                    context.tr(uz: 'sm', ru: 'см', en: 'cm'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('vitals-bmi-weight'),
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: digits,
                  decoration: deco(
                    context.tr(uz: 'Vazn', ru: 'Вес', en: 'Weight'),
                    context.tr(uz: 'kg', ru: 'кг', en: 'kg'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (value == null)
            Text(
              context.tr(
                uz: 'Bo‘y (100–250 sm) va vaznni (20–300 kg) kiriting',
                ru: 'Введите рост (100–250 см) и вес (20–300 кг)',
                en: 'Enter height (100–250 cm) and weight (20–300 kg)',
              ),
              style: text.bodySmall,
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value.toStringAsFixed(1),
                  key: const Key('vitals-bmi-value'),
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  info?.text ?? '',
                  key: const Key('vitals-bmi-level'),
                  style: text.titleSmall?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Scale(value: value),
            const SizedBox(height: 6),
            Text(
              context.tr(
                uz: 'Me’yor: 18.5–24.9. Sportchilar va keksalarda TVI aniq emas.',
                ru: 'Норма: 18,5–24,9. У спортсменов и пожилых ИМТ неточен.',
                en:
                    'Normal: 18.5–24.9. BMI is less accurate for athletes and '
                    'older people.',
              ),
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// 15…40 scale in four colour zones with a marker.
class _Scale extends StatelessWidget {
  const _Scale({required this.value});

  final double value;

  static const _min = 15.0, _max = 40.0;

  @override
  Widget build(BuildContext context) {
    double f(double v) => ((v - _min) / (_max - _min)).clamp(0.0, 1.0);
    final zones = [
      (18.5 - _min, AppColors.sky),
      (25 - 18.5, AppColors.good),
      (30 - 25.0, AppColors.amber),
      (_max - 30, AppColors.danger),
    ];
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        height: 18,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 5,
              bottom: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Row(
                  children: [
                    for (final z in zones)
                      Expanded(
                        flex: (z.$1 * 10).round(),
                        child: ColoredBox(color: z.$2.withValues(alpha: 0.7)),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: f(value) * c.maxWidth - 9,
              top: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
