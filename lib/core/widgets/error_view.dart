import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_lang.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// Human-readable (uz/ru/en) description of [error] for end users.
/// Raw exception text is never shown in release builds.
String errorMessage(BuildContext context, Object? error) {
  final raw = '$error';
  final network =
      error is http.ClientException ||
      error is AuthRetryableFetchException ||
      raw.contains('SocketException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Connection refused') ||
      raw.contains('Network is unreachable');
  if (network) {
    return context.tr(
      uz: 'Internet aloqasi yo‘q. Tarmoqni tekshirib, qayta urinib ko‘ring.',
      ru: 'Нет подключения к интернету. Проверьте сеть и повторите.',
      en: 'No internet connection. Check your network and try again.',
    );
  }
  if (error is TimeoutException) {
    return context.tr(
      uz: 'Server javob bermadi. Birozdan so‘ng qayta urinib ko‘ring.',
      ru: 'Сервер не ответил. Попробуйте чуть позже.',
      en: 'The server did not respond. Please try again shortly.',
    );
  }
  if (error is PostgrestException) {
    final denied =
        error.code == '42501' ||
        error.code == 'PGRST301' ||
        error.message.contains('permission denied');
    return denied
        ? context.tr(
            uz: 'Bu ma’lumotlarga ruxsat yo‘q. Qayta kirib ko‘ring.',
            ru: 'Нет доступа к этим данным. Попробуйте войти заново.',
            en: 'No access to this data. Try signing in again.',
          )
        : context.tr(
            uz: 'Ma’lumotlarni yuklab bo‘lmadi.',
            ru: 'Не удалось загрузить данные.',
            en: 'Could not load data.',
          );
  }
  if (error is AuthException) {
    return context.tr(
      uz: 'Sessiya tugadi. Iltimos, qayta kiring.',
      ru: 'Сессия истекла. Пожалуйста, войдите снова.',
      en: 'Your session has expired. Please sign in again.',
    );
  }
  return context.tr(
    uz: 'Nimadir noto‘g‘ri ketdi. Qayta urinib ko‘ring.',
    ru: 'Что-то пошло не так. Попробуйте ещё раз.',
    en: 'Something went wrong. Please try again.',
  );
}

/// Error state with optional retry. Use for every `AsyncValue.error`
/// (or just use `AsyncValueView`).
///
/// [compact] renders an inline card for use inside lists / sections.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.error, this.onRetry, this.compact = false});

  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = context.tr(
      uz: 'Xatolik yuz berdi',
      ru: 'Произошла ошибка',
      en: 'Something went wrong',
    );
    final message = errorMessage(context, error);
    final retryLabel = context.tr(
      uz: 'Qayta urinish',
      ru: 'Повторить',
      en: 'Retry',
    );

    if (compact) {
      return AppCard(
        elevated: false,
        color: AppColors.danger.withValues(alpha: 0.08),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: text.bodyMedium)),
            if (onRetry != null)
              IconButton(
                tooltip: retryLabel,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.danger.withValues(alpha: 0.18),
                    AppColors.danger.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (kDebugMode && error != null) ...[
              const SizedBox(height: 8),
              Text(
                '$error',
                style: text.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
