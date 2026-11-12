import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pill.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../application/health_index.dart';

const disclaimerUz = 'Shifokor maslahatini almashtirmaydi';

Color indexColor(int score) => switch (score) {
  >= 80 => AppColors.good,
  >= 60 => AppColors.primary,
  >= 40 => AppColors.amber,
  _ => AppColors.coral,
};

String _level(BuildContext c, int score) => switch (score) {
  >= 80 => c.tr(uz: 'A’lo', ru: 'Отлично', en: 'Excellent'),
  >= 60 => c.tr(uz: 'Yaxshi', ru: 'Хорошо', en: 'Good'),
  >= 40 => c.tr(uz: 'O‘rtacha', ru: 'Средне', en: 'Fair'),
  _ => c.tr(uz: 'E’tibor bering', ru: 'Обратите внимание', en: 'Needs care'),
};

String _bmiLabel(BuildContext c, BmiCategory cat) => switch (cat) {
  BmiCategory.under => c.tr(
    uz: 'me’yordan past',
    ru: 'ниже нормы',
    en: 'below normal',
  ),
  BmiCategory.normal => c.tr(uz: 'me’yorda', ru: 'в норме', en: 'normal'),
  BmiCategory.over => c.tr(
    uz: 'me’yordan yuqori',
    ru: 'выше нормы',
    en: 'above normal',
  ),
  BmiCategory.obese => c.tr(
    uz: 'ancha yuqori',
    ru: 'значительно выше',
    en: 'well above normal',
  ),
};

String _factorLabel(BuildContext c, IndexFactor f) => switch (f) {
  IndexFactor.bmi => c.tr(
    uz: 'Tana vazni indeksi',
    ru: 'Индекс массы тела',
    en: 'Body mass index',
  ),
  IndexFactor.age => c.tr(uz: 'Yosh', ru: 'Возраст', en: 'Age'),
  IndexFactor.medical => c.tr(
    uz: 'Tibbiy ma’lumotlar',
    ru: 'Медицинские данные',
    en: 'Medical data',
  ),
  IndexFactor.activity => c.tr(uz: 'Faollik', ru: 'Активность', en: 'Activity'),
};

String _tipText(BuildContext c, HealthTip t) => switch (t) {
  HealthTip.lowerWeight => c.tr(
    uz: 'Ovqatlanish rejasi vaznni me’yorga keltirishga yordam beradi',
    ru: 'План питания поможет привести вес к норме',
    en: 'A meal plan helps bring weight to normal',
  ),
  HealthTip.gainWeight => c.tr(
    uz: 'Vazn me’yordan past — ovqatlanishni kuzating',
    ru: 'Вес ниже нормы — следите за питанием',
    en: 'Weight is below normal — watch your diet',
  ),
  HealthTip.addBloodType => c.tr(
    uz: 'Profilga qon guruhini qo‘shing',
    ru: 'Добавьте группу крови в профиль',
    en: 'Add your blood type to the profile',
  ),
  HealthTip.startActivity => c.tr(
    uz: 'Kuniga 30 daqiqa harakat — indeks oshadi',
    ru: '30 минут движения в день — индекс вырастет',
    en: '30 minutes of movement a day raises the index',
  ),
};

String _tipRoute(HealthTip t) => switch (t) {
  HealthTip.lowerWeight || HealthTip.gainWeight => AppRoutes.nutrition,
  HealthTip.addBloodType => AppRoutes.profile,
  HealthTip.startActivity => AppRoutes.workouts,
};

String _bmiText(BuildContext c, HealthIndex index) =>
    '${c.tr(uz: 'TVI', ru: 'ИМТ', en: 'BMI')} '
    '${index.bmi.toStringAsFixed(1)} · ${_bmiLabel(c, index.bmiCategory)}';

/// «Bugungi salomatlik indeksi» — ring with the score, level, BMI and the
/// first tip. Tap opens the breakdown.
class HealthIndexCard extends StatelessWidget {
  const HealthIndexCard({super.key, required this.index});

  final HealthIndex index;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final score = index.score;
    final color = indexColor(score);
    return AppCard(
      onTap: () => showHealthIndexDetails(context, index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                value: score / 100,
                size: 92,
                strokeWidth: 10,
                color: color,
                child: Text(
                  '$score',
                  key: const ValueKey('health-index-score'),
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        uz: 'Bugungi salomatlik indeksi',
                        ru: 'Индекс здоровья сегодня',
                        en: 'Today’s health index',
                      ),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Pill(_level(context, score), color: color),
                    const SizedBox(height: 6),
                    Text(_bmiText(context, index), style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (index.tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('💡'),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tipText(context, index.tips.first),
                    style: text.bodyMedium,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            context.tr(
              uz: disclaimerUz,
              ru: 'Не заменяет консультацию врача',
              en: 'Does not replace a doctor’s advice',
            ),
            style: text.labelSmall?.copyWith(color: text.bodySmall?.color),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: how the score was computed and what to do next.
Future<void> showHealthIndexDetails(BuildContext context, HealthIndex index) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheet.tr(
                  uz: 'Indeks qanday hisoblanadi',
                  ru: 'Как считается индекс',
                  en: 'How the index is calculated',
                ),
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                sheet.tr(
                  uz:
                      'Hozircha profil ma’lumotlari bo‘yicha. Faollik va '
                      'ko‘rsatkichlar qo‘shilsa, aniqroq bo‘ladi.',
                  ru:
                      'Пока по данным профиля. С активностью и показателями '
                      'станет точнее.',
                  en:
                      'Based on your profile for now. Activity and vitals '
                      'will make it more accurate.',
                ),
                style: text.bodySmall,
              ),
              const SizedBox(height: 16),
              for (final part in index.parts) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _factorLabel(sheet, part.factor),
                        style: text.bodyMedium,
                      ),
                    ),
                    Text(
                      '${part.points} / ${part.factor.max}',
                      style: text.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: part.points / part.factor.max,
                    minHeight: 8,
                    color: indexColor(
                      (part.points / part.factor.max * 100).round(),
                    ),
                  ),
                ),
                if (part.factor == IndexFactor.bmi) ...[
                  const SizedBox(height: 4),
                  Text(_bmiText(sheet, index), style: text.bodySmall),
                ],
                const SizedBox(height: 14),
              ],
              if (index.tips.isNotEmpty) ...[
                Text(
                  sheet.tr(uz: 'Tavsiyalar', ru: 'Советы', en: 'Tips'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final tip in index.tips)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Text('💡', style: TextStyle(fontSize: 20)),
                    title: Text(_tipText(sheet, tip)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(sheet).pop();
                      context.go(_tipRoute(tip));
                    },
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                sheet.tr(
                  uz: disclaimerUz,
                  ru: 'Не заменяет консультацию врача',
                  en: 'Does not replace a doctor’s advice',
                ),
                style: text.labelSmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}
