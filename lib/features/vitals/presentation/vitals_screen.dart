import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

class VitalsScreen extends StatelessWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(uz: 'Ko‘rsatkichlar', ru: 'Показатели', en: 'Vitals'),
      body: EmptyState(
        emoji: '❤️',
        title: context.tr(
          uz: 'Ko‘rsatkichlar — tez orada',
          ru: 'Показатели — скоро',
          en: 'Vitals — coming soon',
        ),
      ),
    );
  }
}
