import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(uz: 'Ovqat', ru: 'Питание', en: 'Nutrition'),
      body: EmptyState(
        emoji: '🥗',
        title: context.tr(
          uz: 'Ovqat — tez orada',
          ru: 'Питание — скоро',
          en: 'Nutrition — coming soon',
        ),
      ),
    );
  }
}
