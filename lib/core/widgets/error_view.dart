import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../theme/app_colors.dart';

/// Error state with optional retry. Use for every `AsyncValue.error`.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.error, this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              context.tr(
                uz: 'Xatolik yuz berdi',
                ru: 'Произошла ошибка',
                en: 'Something went wrong',
              ),
              style: text.titleMedium,
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                '$error',
                style: text.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(
                  context.tr(uz: 'Qayta urinish', ru: 'Повторить', en: 'Retry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
