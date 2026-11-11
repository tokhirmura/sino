import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

class DoctorsScreen extends StatelessWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(uz: 'Shifokorlar', ru: 'Врачи', en: 'Doctors'),
      body: EmptyState(
        emoji: '🩺',
        title: context.tr(
          uz: 'Shifokorlar — tez orada',
          ru: 'Врачи — скоро',
          en: 'Doctors — coming soon',
        ),
      ),
    );
  }
}
