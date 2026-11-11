import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_lang.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: context.tr(uz: 'Asosiy', ru: 'Главная', en: 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.medication_outlined),
            selectedIcon: const Icon(Icons.medication),
            label: context.tr(uz: 'Dorixona', ru: 'Аптека', en: 'Pharmacy'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: context.tr(uz: 'Ovqat', ru: 'Питание', en: 'Food'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: context.tr(uz: 'Sport', ru: 'Спорт', en: 'Sport'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.tr(uz: 'Profil', ru: 'Профиль', en: 'Profile'),
          ),
        ],
      ),
    );
  }
}
