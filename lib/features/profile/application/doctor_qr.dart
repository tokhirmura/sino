import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/data/user.dart';
import '../data/medical_repository.dart';

/// What the user agrees to show the doctor in the QR.
enum QrField { basics, bloodType, allergies, diagnoses, prescriptions, labs }

/// Same signature as `context.tr`, so the text follows the UI language.
typedef Tr = String Function({required String uz, String? ru, String? en});

/// Plain text — readable by any QR scanner, no app or network needed.
/// Only the user's own records (not family). Max ~5 items per list.
String buildDoctorQrText({
  required UserProfile profile,
  required List<MedicalRecord> records,
  required List<LabResult> labs,
  required Set<QrField> fields,
  required Tr tr,
  DateTime? now,
}) {
  final day = DateFormat('dd.MM.yyyy');
  final own = [
    for (final r in records)
      if (r.memberId == null) r,
  ];
  final lines = <String>[
    'SINO — ${tr(uz: 'Tibbiy karta', ru: 'Медкарта', en: 'Medical card')}',
  ];

  if (fields.contains(QrField.basics)) {
    lines.add('${tr(uz: 'Ism', ru: 'Имя', en: 'Name')}: ${profile.fullName}');
    final year = (now ?? DateTime.now()).year;
    if (profile.birthYear != null) {
      lines.add(
        '${tr(uz: 'Tug‘ilgan yil', ru: 'Год рождения', en: 'Born')}: '
        '${profile.birthYear} (${year - profile.birthYear!})',
      );
    }
    if (profile.heightCm != null && profile.weightKg != null) {
      lines.add(
        '${tr(uz: 'Bo‘y/vazn', ru: 'Рост/вес', en: 'Height/weight')}: '
        '${_num(profile.heightCm!)} sm / ${_num(profile.weightKg!)} kg',
      );
    }
  }
  if (fields.contains(QrField.bloodType)) {
    lines.add(
      '${tr(uz: 'Qon guruhi', ru: 'Группа крови', en: 'Blood type')}: '
      '${profile.bloodType ?? '—'}',
    );
  }
  if (fields.contains(QrField.allergies)) {
    lines.add(
      '${tr(uz: 'Allergiya', ru: 'Аллергия', en: 'Allergies')}: '
      '${profile.allergies.isEmpty ? '—' : profile.allergies.join(', ')}',
    );
  }

  void section(String title, Iterable<String> items) {
    final list = items.take(5).toList();
    if (list.isEmpty) return;
    lines
      ..add('')
      ..add('$title:')
      ..addAll(list.map((s) => '- $s'));
  }

  if (fields.contains(QrField.diagnoses)) {
    section(tr(uz: 'Tashxislar', ru: 'Диагнозы', en: 'Diagnoses'), [
      for (final r in own)
        if (r.kind == 'diagnosis') '${r.title} (${day.format(r.date)})',
    ]);
  }
  if (fields.contains(QrField.prescriptions)) {
    section(tr(uz: 'Retseptlar', ru: 'Рецепты', en: 'Prescriptions'), [
      for (final r in own)
        if (r.kind == 'prescription')
          '${r.title}${r.notes == null ? '' : ' — ${r.notes}'} '
              '(${day.format(r.date)})',
    ]);
  }
  if (fields.contains(QrField.labs)) {
    section(tr(uz: 'Tahlillar', ru: 'Анализы', en: 'Lab results'), [
      for (final l in labs)
        '${l.name}: ${_num(l.value)}${l.unit == null ? '' : ' ${l.unit}'}'
            '${l.status == LabStatus.normal ? '' : ' (!)'} '
            '(${day.format(l.takenAt)})',
    ]);
  }
  return lines.join('\n');
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Chosen fields; default — what a doctor needs first.
class QrFieldsNotifier extends Notifier<Set<QrField>> {
  @override
  Set<QrField> build() => {
    QrField.basics,
    QrField.bloodType,
    QrField.allergies,
    QrField.diagnoses,
  };

  void toggle(QrField f) =>
      state = state.contains(f) ? ({...state}..remove(f)) : {...state, f};
}

final qrFieldsProvider = NotifierProvider<QrFieldsNotifier, Set<QrField>>(
  QrFieldsNotifier.new,
);
