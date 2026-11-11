import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: context.tr(uz: 'Yordamchi', ru: 'Ассистент', en: 'Assistant'),
      body: EmptyState(
        emoji: '🤖',
        title: context.tr(
          uz: 'Yordamchi — tez orada',
          ru: 'Ассистент — скоро',
          en: 'Assistant — coming soon',
        ),
      ),
    );
  }
}
