import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_lang.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';

/// Tabs shell. Design 2.0: a floating rounded bar with a soft shadow,
/// pill indicator and gradient (turquoise → lapis) selected icons.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: shell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppShadows.soft(theme.brightness),
              border: isDark
                  ? Border.all(color: theme.colorScheme.outlineVariant)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: NavigationBar(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: (i) => shell.goBranch(
                    i,
                    initialLocation: i == shell.currentIndex,
                  ),
                  destinations: [
                    _dest(
                      context,
                      Icons.home_outlined,
                      Icons.home_rounded,
                      context.tr(uz: 'Asosiy', ru: 'Главная', en: 'Home'),
                    ),
                    _dest(
                      context,
                      Icons.medication_outlined,
                      Icons.medication_rounded,
                      context.tr(uz: 'Dorixona', ru: 'Аптека', en: 'Pharmacy'),
                    ),
                    _dest(
                      context,
                      Icons.restaurant_outlined,
                      Icons.restaurant_rounded,
                      context.tr(uz: 'Ovqat', ru: 'Питание', en: 'Food'),
                    ),
                    _dest(
                      context,
                      Icons.fitness_center_outlined,
                      Icons.fitness_center_rounded,
                      context.tr(uz: 'Sport', ru: 'Спорт', en: 'Sport'),
                    ),
                    _dest(
                      context,
                      Icons.person_outline,
                      Icons.person_rounded,
                      context.tr(uz: 'Profil', ru: 'Профиль', en: 'Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  NavigationDestination _dest(
    BuildContext context,
    IconData icon,
    IconData selected,
    String label,
  ) {
    final brightness = Theme.of(context).brightness;
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => AppColors.brand(brightness).createShader(r),
        child: Icon(selected, color: Colors.white),
      ),
      label: label,
    );
  }
}
