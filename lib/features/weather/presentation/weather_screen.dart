import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(uz: 'Ob-havo', ru: 'Погода', en: 'Weather'),
      body: EmptyState(
        emoji: '🌤️',
        title: context.tr(
          uz: 'Ob-havo — tez orada',
          ru: 'Погода — скоро',
          en: 'Weather — coming soon',
        ),
      ),
    );
  }
}
