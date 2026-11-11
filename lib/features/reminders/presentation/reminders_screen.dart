import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(uz: 'Eslatmalar', ru: 'Напоминания', en: 'Reminders'),
      body: EmptyState(
        emoji: '⏰',
        title: context.tr(
          uz: 'Eslatmalar — tez orada',
          ru: 'Напоминания — скоро',
          en: 'Reminders — coming soon',
        ),
      ),
    );
  }
}
