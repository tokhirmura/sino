import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(uz: 'SOS', ru: 'SOS', en: 'SOS'),
      body: EmptyState(
        emoji: '🆘',
        title: context.tr(
          uz: 'SOS — tez orada',
          ru: 'SOS — скоро',
          en: 'SOS — coming soon',
        ),
      ),
    );
  }
}
