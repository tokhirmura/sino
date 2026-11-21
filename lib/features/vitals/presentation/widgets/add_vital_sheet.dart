import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../application/vitals_math.dart';
import '../../data/models.dart';
import '../labels.dart';

typedef NewVital = ({VitalKind kind, double value, double? value2});

/// Bottom sheet to enter a measurement; `null` when closed.
Future<NewVital?> showAddVitalSheet(BuildContext context, VitalKind kind) =>
    showModalBottomSheet<NewVital>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddVitalSheet(initial: kind),
    );

class _AddVitalSheet extends StatefulWidget {
  const _AddVitalSheet({required this.initial});

  final VitalKind initial;

  @override
  State<_AddVitalSheet> createState() => _AddVitalSheetState();
}

class _AddVitalSheetState extends State<_AddVitalSheet> {
  late VitalKind _kind = widget.initial;
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _value2 = TextEditingController();

  /// Diastolic not below systolic (shown under the fields).
  bool _pairError = false;

  @override
  void dispose() {
    _value.dispose();
    _value2.dispose();
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  String? _validate(String? s, {bool second = false}) {
    final v = _parse(s ?? '');
    final r = inputRange(_kind, second: second);
    String f(double x) => formatNumber(_kind, x);
    if (v == null) {
      return context.tr(
        uz: 'Raqam kiriting',
        ru: 'Введите число',
        en: 'Enter a number',
      );
    }
    if (v < r.min || v > r.max) {
      return context.tr(
        uz: '${f(r.min)}–${f(r.max)} oralig‘ida bo‘lsin',
        ru: 'Должно быть от ${f(r.min)} до ${f(r.max)}',
        en: 'Must be between ${f(r.min)} and ${f(r.max)}',
      );
    }
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final v1 = _parse(_value.text)!;
    final v2 = _kind.hasSecondValue ? _parse(_value2.text) : null;
    if (v2 != null && v2 >= v1) {
      setState(() => _pairError = true);
      return;
    }
    Navigator.pop<NewVital>(context, (kind: _kind, value: v1, value2: v2));
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    // Two pressure fields are narrow: their unit is in the hint below.
    suffixText: _kind.hasSecondValue ? null : _kind.unitText(context),
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final formatter = FilteringTextInputFormatter.allow(
      RegExp(_kind.decimal ? r'[0-9.,]' : r'[0-9]'),
    );
    final keyboard = TextInputType.numberWithOptions(decimal: _kind.decimal);
    // Scrolls when it does not fit (iPhone SE with large text + keyboard).
    return SingleChildScrollView(
      child: _content(context, text, formatter, keyboard),
    );
  }

  Widget _content(
    BuildContext context,
    TextTheme text,
    TextInputFormatter formatter,
    TextInputType keyboard,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(
                uz: 'Yangi o‘lchov',
                ru: 'Новое измерение',
                en: 'New measurement',
              ),
              style: text.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in VitalKind.values)
                  ChoiceChip(
                    key: Key('vitals-add-kind-${k.name}'),
                    label: Text('${k.emoji} ${k.label(context)}'),
                    selected: _kind == k,
                    onSelected: (_) => setState(() {
                      _kind = k;
                      _pairError = false;
                      _value.clear();
                      _value2.clear();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('vitals-add-value'),
                    controller: _value,
                    autofocus: true,
                    keyboardType: keyboard,
                    inputFormatters: [formatter],
                    decoration: _decoration(
                      _kind.hasSecondValue
                          ? context.tr(
                              uz: 'Yuqori',
                              ru: 'Верхнее',
                              en: 'Systolic',
                            )
                          : _kind.label(context),
                    ),
                    validator: _validate,
                  ),
                ),
                if (_kind.hasSecondValue) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('vitals-add-value2'),
                      controller: _value2,
                      keyboardType: keyboard,
                      inputFormatters: [formatter],
                      decoration: _decoration(
                        context.tr(uz: 'Pastki', ru: 'Нижнее', en: 'Diastolic'),
                      ),
                      validator: (s) => _validate(s, second: true),
                    ),
                  ),
                ],
              ],
            ),
            if (_pairError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.tr(
                    uz: 'Pastki bosim yuqorisidan kichik bo‘lishi kerak',
                    ru: 'Нижнее давление должно быть меньше верхнего',
                    en: 'Diastolic must be lower than systolic',
                  ),
                  key: const Key('vitals-add-pair-error'),
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (_kind.normText() != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(
                  uz: 'Umumiy me’yor: ${_kind.normText()} ${_kind.unitText(context)}',
                  ru: 'Общий ориентир: ${_kind.normText()} ${_kind.unitText(context)}',
                  en: 'General range: ${_kind.normText()} ${_kind.unitText(context)}',
                ),
                style: text.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              key: const Key('vitals-add-save'),
              onPressed: _save,
              icon: Icons.check_rounded,
              label: context.tr(uz: 'Saqlash', ru: 'Сохранить', en: 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
