import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(uz: 'Sport', ru: 'Тренировки', en: 'Workouts'),
      body: EmptyState(
        emoji: '🏃',
        title: context.tr(
          uz: 'Sport — tez orada',
          ru: 'Тренировки — скоро',
          en: 'Workouts — coming soon',
        ),
      ),
    );
  }
}
