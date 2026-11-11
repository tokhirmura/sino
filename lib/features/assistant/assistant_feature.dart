import 'package:go_router/go_router.dart';

import '../../core/contracts/home_card.dart';
import '../../core/l10n/app_lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/routing/app_routes.dart';
import 'presentation/assistant_screen.dart';

/// The ONLY public file of the `assistant` feature.
final List<RouteBase> assistantRoutes = [
  GoRoute(
    path: AppRoutes.assistant,
    builder: (context, state) => const AssistantScreen(),
  ),
];

final List<HomeCardSpec> assistantHomeCards = [
  HomeCardSpec(
    id: 'assistant',
    order: 90,
    builder: (context) => ShortcutCard(
      emoji: '🤖',
      title: context.tr(uz: 'Yordamchi', ru: 'Ассистент', en: 'Assistant'),
      subtitle: context.tr(
        uz: 'Savolingizni yozing',
        ru: 'Задайте вопрос',
        en: 'Ask a question',
      ),
      color: AppColors.violet,
      onTap: () => context.push(AppRoutes.assistant),
    ),
  ),
];
