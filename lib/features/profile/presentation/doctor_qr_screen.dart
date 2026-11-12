import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/section_title.dart';
import '../application/doctor_qr.dart';
import '../data/medical_repository.dart';

String _fieldLabel(BuildContext c, QrField f) => switch (f) {
  QrField.basics => c.tr(
    uz: 'Ism, yosh, bo‘y va vazn',
    ru: 'Имя, возраст, рост и вес',
    en: 'Name, age, height and weight',
  ),
  QrField.bloodType => c.tr(
    uz: 'Qon guruhi',
    ru: 'Группа крови',
    en: 'Blood type',
  ),
  QrField.allergies => c.tr(
    uz: 'Allergiyalar',
    ru: 'Аллергии',
    en: 'Allergies',
  ),
  QrField.diagnoses => c.tr(uz: 'Tashxislar', ru: 'Диагнозы', en: 'Diagnoses'),
  QrField.prescriptions => c.tr(
    uz: 'Retseptlar',
    ru: 'Рецепты',
    en: 'Prescriptions',
  ),
  QrField.labs => c.tr(
    uz: 'Oxirgi tahlillar',
    ru: 'Последние анализы',
    en: 'Recent lab results',
  ),
};

/// QR for the doctor: the user picks what is visible; the QR holds plain
/// text, so any scanner reads it without the app or internet.
class DoctorQrScreen extends ConsumerWidget {
  const DoctorQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final records = ref.watch(medicalRecordsProvider);
    final labs = ref.watch(labResultsProvider);
    final fields = ref.watch(qrFieldsProvider);

    Widget body() {
      if (user.hasError) {
        return ErrorView(
          error: user.error!,
          onRetry: () => ref.invalidate(currentUserProvider),
        );
      }
      final failed = records.hasError ? records : labs;
      if (failed.hasError) {
        return ErrorView(
          error: failed.error!,
          onRetry: () => ref
            ..invalidate(medicalRecordsProvider)
            ..invalidate(labResultsProvider),
        );
      }
      final profile = user.value;
      if (profile == null || !records.hasValue || !labs.hasValue) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = buildDoctorQrText(
        profile: profile,
        records: records.value!,
        labs: labs.value!,
        fields: fields,
        tr: context.tr,
      );
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Text(
            context.tr(
              uz:
                  'Shifokorga ko‘rsating — u telefon kamerasi bilan o‘qiydi. '
                  'Internet kerak emas.',
              ru:
                  'Покажите врачу — он считает камерой телефона. Интернет '
                  'не нужен.',
              en:
                  'Show it to your doctor — any phone camera reads it. No '
                  'internet needed.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          AppCard(
            // QR must stay dark-on-white in both themes to scan reliably.
            color: Colors.white,
            child: Center(
              child: QrImageView(
                key: const ValueKey('doctor-qr'),
                data: data,
                size: 260,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                semanticsLabel: context.tr(
                  uz: 'Shifokor uchun QR-kod',
                  ru: 'QR-код для врача',
                  en: 'QR code for the doctor',
                ),
              ),
            ),
          ),
          SectionTitle(
            context.tr(
              uz: 'QR’da nima ko‘rinadi',
              ru: 'Что видно в QR',
              en: 'What the QR shows',
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final f in QrField.values)
                  SwitchListTile(
                    title: Text(_fieldLabel(context, f)),
                    value: fields.contains(f),
                    onChanged: (_) =>
                        ref.read(qrFieldsProvider.notifier).toggle(f),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              context.tr(uz: 'QR matni', ru: 'Текст QR', en: 'QR text'),
            ),
            children: [
              SelectableText(
                data,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      );
    }

    return AppScaffold(
      title: context.tr(
        uz: 'Shifokor uchun QR',
        ru: 'QR для врача',
        en: 'QR for the doctor',
      ),
      body: body(),
    );
  }
}
