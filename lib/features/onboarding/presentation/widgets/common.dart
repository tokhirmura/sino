import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';

/// UZ / RU / EN switch shown before sign-in.
class LangSwitcher extends ConsumerWidget {
  const LangSwitcher({super.key, this.onDark = false});

  /// White version for a gradient background.
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLangProvider);
    const compact = ButtonStyle(visualDensity: VisualDensity.compact);
    return SegmentedButton<AppLang>(
      showSelectedIcon: false,
      style: onDark
          ? compact.copyWith(
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.06),
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: Colors.white.withValues(alpha: 0.45)),
              ),
            )
          : compact,
      segments: [
        for (final l in AppLang.values)
          ButtonSegment(value: l, label: Text(l.name.toUpperCase())),
      ],
      selected: {lang},
      onSelectionChanged: (s) =>
          ref.read(appLangProvider.notifier).set(s.first),
    );
  }
}

/// Back arrow + title row for the inner steps (email, OneID).
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          tooltip: context.tr(uz: 'Orqaga', ru: 'Назад', en: 'Back'),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Tinted inline message: error (red) or info (primary).
class InlineMessage extends StatelessWidget {
  const InlineMessage.error(this.text, {super.key}) : isError = true;
  const InlineMessage.info(this.text, {super.key}) : isError = false;

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Spinner sized for a button label.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

/// Full-width outlined button matching the filled button theme.
final ButtonStyle wideOutlinedStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);
