import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/app_lang.dart';
import '../labels.dart';

/// «Penitsillin, aspirin» → ['Penitsillin', 'aspirin'].
List<String> parseAllergies(String raw) => [
  for (final s in raw.split(RegExp(r'[,;\n]')))
    if (s.trim().isNotEmpty) s.trim(),
];

String? validateName(BuildContext c, String? v) => (v ?? '').trim().length < 2
    ? c.tr(uz: 'Ismni kiriting', ru: 'Введите имя', en: 'Enter a name')
    : null;

/// Optional for family members ([required] false), required for the user.
String? validateBirthYear(BuildContext c, String? v, {bool required = true}) {
  final s = (v ?? '').trim();
  if (s.isEmpty && !required) return null;
  final year = int.tryParse(s);
  final now = DateTime.now().year;
  if (year == null || year < 1900 || year > now) {
    return c.tr(
      uz: '1900–$now oralig‘ida yil kiriting',
      ru: 'Введите год от 1900 до $now',
      en: 'Enter a year from 1900 to $now',
    );
  }
  return null;
}

/// Number in [min]..[max]; comma is accepted as the decimal separator.
String? validateRange(BuildContext c, String? v, double min, double max) {
  final n = parseDecimal(v);
  if (n == null || n < min || n > max) {
    return c.tr(
      uz: '${formatNum(min)}–${formatNum(max)} oralig‘ida',
      ru: 'От ${formatNum(min)} до ${formatNum(max)}',
      en: 'From ${formatNum(min)} to ${formatNum(max)}',
    );
  }
  return null;
}

double? parseDecimal(String? v) =>
    double.tryParse((v ?? '').trim().replaceAll(',', '.'));

final digitsOnly = FilteringTextInputFormatter.digitsOnly;
final decimalOnly = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// Dropdown of [bloodTypes] + «don't know»; keeps an unknown stored value.
class BloodTypeField extends StatelessWidget {
  const BloodTypeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      ...bloodTypes,
      if (value != null && !bloodTypes.contains(value)) value!,
    ];
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: context.tr(
          uz: 'Qon guruhi',
          ru: 'Группа крови',
          en: 'Blood type',
        ),
        prefixIcon: const Icon(Icons.bloodtype_outlined),
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(
            context.tr(uz: 'Bilmayman', ru: 'Не знаю', en: 'Don’t know'),
          ),
        ),
        for (final t in options) DropdownMenuItem(value: t, child: Text(t)),
      ],
      onChanged: onChanged,
    );
  }
}

class AllergiesField extends StatelessWidget {
  const AllergiesField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: context.tr(uz: 'Allergiya', ru: 'Аллергия', en: 'Allergies'),
      hintText: context.tr(
        uz: 'Vergul bilan: penitsillin, yong‘oq',
        ru: 'Через запятую: пенициллин, орехи',
        en: 'Comma separated: penicillin, nuts',
      ),
      prefixIcon: const Icon(Icons.warning_amber_outlined),
    ),
  );
}

/// Shows an inline error under a form (save failed).
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

String saveErrorText(BuildContext c, Object e) => c.tr(
  uz: 'Saqlab bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',
  ru: 'Не удалось сохранить. Проверьте интернет и попробуйте снова.',
  en: 'Could not save. Check the internet and try again.',
);
