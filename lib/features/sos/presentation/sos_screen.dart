import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/emoji_box.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/section_title.dart';
import '../application/sos_controller.dart';
import '../data/first_aid.dart';
import 'sos_paths.dart';
import 'widgets/hold_button.dart';

/// Uzbekistan emergency numbers.
class _Service {
  const _Service(this.number, this.emoji, this.label);
  final String number;
  final String emoji;
  final String Function(BuildContext) label;
}

final _services = [
  _Service(
    '103',
    '🚑',
    (c) => c.tr(uz: 'Tez yordam', ru: 'Скорая помощь', en: 'Ambulance'),
  ),
  _Service(
    '101',
    '🚒',
    (c) => c.tr(uz: 'Yong‘in xizmati', ru: 'Пожарная служба', en: 'Fire'),
  ),
  _Service(
    '102',
    '🚓',
    (c) => c.tr(uz: 'Ichki ishlar', ru: 'Полиция', en: 'Police'),
  ),
  _Service(
    '104',
    '🔥',
    (c) => c.tr(uz: 'Gaz xizmati', ru: 'Газовая служба', en: 'Gas service'),
  ),
];

/// Opens [uri] (dialer / SMS); shows a hint when nothing can handle it.
Future<void> openExternal(
  BuildContext context,
  WidgetRef ref,
  Uri uri, {
  required String fallback,
}) async {
  var ok = false;
  try {
    ok = await ref.read(externalLauncherProvider)(uri);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(fallback)));
  }
}

Future<void> callNumber(BuildContext context, WidgetRef ref, String number) =>
    openExternal(
      context,
      ref,
      telUri(number),
      fallback: context.tr(
        uz: 'Qo‘ng‘iroq ochilmadi — $number raqamini qo‘lda tering.',
        ru: 'Не удалось открыть звонок — наберите $number вручную.',
        en: 'Couldn’t open the dialer — dial $number manually.',
      ),
    );

/// SOS: hold-to-alert, quick dial, info for medics, offline first aid.
class SosScreen extends ConsumerWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(sosAlertProvider);
    final text = Theme.of(context).textTheme;
    return AppScaffold(
      title: 'SOS',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Text(
            context.tr(
              uz:
                  'Tugmani 2 soniya bosib turing — joylashuvingiz '
                  'yaqinlaringizga yuboriladi.',
              ru:
                  'Удерживайте кнопку 2 секунды — близкие получат вашу '
                  'геопозицию.',
              en:
                  'Hold the button for 2 seconds — your family gets your '
                  'location.',
            ),
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: HoldToConfirmButton(
              enabled: !(alert?.isLoading ?? false),
              onConfirmed: () => ref.read(sosAlertProvider.notifier).trigger(),
            ),
          ),
          const SizedBox(height: 16),
          if (alert != null) _AlertResult(alert: alert),
          SectionTitle(
            context.tr(
              uz: 'Tezkor qo‘ng‘iroq',
              ru: 'Быстрый звонок',
              en: 'Quick call',
            ),
          ),
          const _QuickDial(),
          SectionTitle(
            context.tr(
              uz: 'Shifokorlar uchun',
              ru: 'Для медиков',
              en: 'For medics',
            ),
          ),
          const _MedicalInfo(),
          SectionTitle(
            context.tr(
              uz: 'Birinchi yordam',
              ru: 'Первая помощь',
              en: 'First aid',
            ),
            trailing: Pill(
              context.tr(uz: 'Oflayn', ru: 'Офлайн', en: 'Offline'),
              icon: Icons.wifi_off,
            ),
          ),
          const _FirstAidList(),
          const SizedBox(height: 12),
          Text(
            context.tr(
              uz:
                  'Shifokor maslahatini almashtirmaydi. Xavfli holatda '
                  'birinchi navbatda 103 ga qo‘ng‘iroq qiling.',
              ru:
                  'Не заменяет консультацию врача. В опасной ситуации '
                  'сначала звоните 103.',
              en:
                  'Does not replace a doctor’s advice. In danger, call 103 '
                  'first.',
            ),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AlertResult extends ConsumerWidget {
  const _AlertResult({required this.alert});

  final AsyncValue<SosAlert> alert;

  String _message(BuildContext context, SosAlert a, UserProfile? p) {
    final where = a.point == null
        ? context.tr(
            uz: 'joylashuv aniqlanmadi',
            ru: 'геопозиция не определена',
            en: 'location unavailable',
          )
        : a.point!.mapsUrl;
    return [
      context.tr(
        uz: 'SOS! Menga yordam kerak. Joylashuvim: $where',
        ru: 'SOS! Мне нужна помощь. Я здесь: $where',
        en: 'SOS! I need help. My location: $where',
      ),
      if (p?.bloodType != null)
        '${context.tr(uz: 'Qon guruhi', ru: 'Группа крови', en: 'Blood type')}: '
            '${p!.bloodType}',
      if (p != null && p.allergies.isNotEmpty)
        '${context.tr(uz: 'Allergiya', ru: 'Аллергия', en: 'Allergies')}: '
            '${p.allergies.join(', ')}',
      '— Sino',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return alert.when(
      loading: () => AppCard(
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr(
                  uz: 'Joylashuv aniqlanmoqda va yuborilmoqda…',
                  ru: 'Определяем геопозицию и отправляем…',
                  en: 'Locating and sending…',
                ),
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.read(sosAlertProvider.notifier).trigger(),
      ),
      data: (a) {
        final profile = ref.watch(currentUserProvider).value;
        final message = _message(context, a, profile);
        return AppCard(
          key: const ValueKey('sos-alert-result'),
          color: AppColors.good.withValues(alpha: 0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.recipients.isEmpty
                          ? context.tr(
                              uz: 'Signal tayyor',
                              ru: 'Сигнал готов',
                              en: 'Alert ready',
                            )
                          : context.tr(
                              uz: 'Yaqinlaringizga yuborildi (demo)',
                              ru: 'Отправлено близким (демо)',
                              en: 'Sent to your family (demo)',
                            ),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr(
                      uz: 'Yopish',
                      ru: 'Закрыть',
                      en: 'Close',
                    ),
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        ref.read(sosAlertProvider.notifier).reset(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                a.recipients.isEmpty
                    ? context.tr(
                        uz:
                            'Yaqinlar ro‘yxati bo‘sh — Profil → Oila bo‘limida '
                            'qo‘shing. Hozir SMS orqali yuboring.',
                        ru:
                            'Список близких пуст — добавьте в Профиль → Семья. '
                            'Сейчас отправьте по SMS.',
                        en:
                            'Your family list is empty — add people in '
                            'Profile → Family. Send by SMS for now.',
                      )
                    : a.recipients.join(', '),
                style: text.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                a.point == null
                    ? context.tr(
                        uz: '📍 Joylashuv aniqlanmadi',
                        ru: '📍 Геопозиция не определена',
                        en: '📍 Location unavailable',
                      )
                    : '📍 ${a.point!.lat.toStringAsFixed(5)}, '
                          '${a.point!.lng.toStringAsFixed(5)}',
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openExternal(
                        context,
                        ref,
                        smsUri(message),
                        fallback: context.tr(
                          uz: 'SMS ilovasi ochilmadi.',
                          ru: 'Не удалось открыть SMS.',
                          en: 'Couldn’t open SMS.',
                        ),
                      ),
                      icon: const Icon(Icons.sms_outlined),
                      label: Text(
                        context.tr(
                          uz: 'SMS yuborish',
                          ru: 'Отправить SMS',
                          en: 'Send SMS',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: () => callNumber(context, ref, '103'),
                      icon: const Icon(Icons.call),
                      label: const Text('103'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickDial extends ConsumerWidget {
  const _QuickDial();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        for (final s in _services)
          AppCard(
            key: ValueKey('dial-${s.number}'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: () => callNumber(context, ref, s.number),
            child: Row(
              children: [
                EmojiBox(emoji: s.emoji, color: AppColors.danger, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.number,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        s.label(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MedicalInfo extends ConsumerWidget {
  const _MedicalInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return user.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(currentUserProvider),
      ),
      data: (p) {
        if (p == null) return const SizedBox.shrink();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  p.fullName,
                  if (p.age != null)
                    context.tr(
                      uz: '${p.age} yosh',
                      ru: '${p.age} лет',
                      en: '${p.age} y.o.',
                    ),
                ].join(', '),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill(
                    p.bloodType ??
                        context.tr(
                          uz: 'Qon guruhi: —',
                          ru: 'Группа крови: —',
                          en: 'Blood type: —',
                        ),
                    color: AppColors.danger,
                    icon: Icons.bloodtype_outlined,
                  ),
                  if (p.allergies.isEmpty)
                    Pill(
                      context.tr(
                        uz: 'Allergiya yo‘q',
                        ru: 'Аллергий нет',
                        en: 'No allergies',
                      ),
                      color: AppColors.good,
                    )
                  else
                    for (final a in p.allergies)
                      Pill(
                        a,
                        color: AppColors.amber,
                        icon: Icons.warning_amber,
                      ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FirstAidList extends ConsumerWidget {
  const _FirstAidList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guides = ref.watch(firstAidProvider);
    return guides.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(firstAidProvider)),
      data: (list) => Column(
        children: [
          for (final g in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ShortcutCard(
                emoji: g.emoji,
                color: AppColors.danger,
                title: context.trMap(g.title),
                subtitle: context.trMap(g.when),
                onTap: () => context.push(SosPaths.firstAid(g.id)),
              ),
            ),
        ],
      ),
    );
  }
}
