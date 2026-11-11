import 'package:flutter/material.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';

/// Stub. [initialQuery] comes from the `/pharmacy?q=<query>` contract.
class PharmacyScreen extends StatelessWidget {
  const PharmacyScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  Widget build(BuildContext context) {
    final q = initialQuery;
    return AppScaffold(
      title: context.tr(uz: 'Dorixona', ru: 'Аптека', en: 'Pharmacy'),
      body: EmptyState(
        emoji: '💊',
        title: context.tr(
          uz: 'Dorixona — tez orada',
          ru: 'Аптека — скоро',
          en: 'Pharmacy — coming soon',
        ),
        message: q == null || q.isEmpty
            ? null
            : context.tr(uz: 'Qidiruv: $q', ru: 'Поиск: $q', en: 'Search: $q'),
      ),
    );
  }
}
