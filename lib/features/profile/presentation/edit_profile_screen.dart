import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import 'labels.dart';
import 'widgets/form_fields.dart';

/// Edit the user's own `profiles` row.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return AppScaffold(
      title: context.tr(
        uz: 'Profilni tahrirlash',
        ru: 'Редактировать профиль',
        en: 'Edit profile',
      ),
      body: user.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (p) =>
            p == null ? const SizedBox.shrink() : _ProfileForm(profile: p),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _year = TextEditingController(
    text: widget.profile.birthYear?.toString() ?? '',
  );
  late final _height = TextEditingController(
    text: _num(widget.profile.heightCm),
  );
  late final _weight = TextEditingController(
    text: _num(widget.profile.weightKg),
  );
  late final _allergies = TextEditingController(
    text: widget.profile.allergies.join(', '),
  );
  late String? _bloodType = widget.profile.bloodType;
  bool _saving = false;
  Object? _error;

  static String _num(double? v) => v == null ? '' : formatNum(v);

  @override
  void dispose() {
    for (final c in [_name, _year, _height, _weight, _allergies]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final p = widget.profile;
    // Built explicitly (not copyWith) so blood type can be cleared.
    final updated = UserProfile(
      id: p.id,
      fullName: _name.text.trim(),
      birthYear: int.parse(_year.text.trim()),
      heightCm: parseDecimal(_height.text),
      weightKg: parseDecimal(_weight.text),
      bloodType: _bloodType,
      allergies: parseAllergies(_allergies.text),
      lang: p.lang,
    );
    try {
      await ref.read(profileRepositoryProvider).save(updated);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.tr(uz: 'Ism', ru: 'Имя', en: 'Name'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (v) => validateName(context, v),
          ),
          gap,
          TextFormField(
            controller: _year,
            keyboardType: TextInputType.number,
            inputFormatters: [digitsOnly],
            decoration: InputDecoration(
              labelText: context.tr(
                uz: 'Tug‘ilgan yil',
                ru: 'Год рождения',
                en: 'Birth year',
              ),
              prefixIcon: const Icon(Icons.cake_outlined),
            ),
            validator: (v) => validateBirthYear(context, v),
          ),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _height,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [decimalOnly],
                  decoration: InputDecoration(
                    labelText: context.tr(
                      uz: 'Bo‘y, sm',
                      ru: 'Рост, см',
                      en: 'Height, cm',
                    ),
                  ),
                  validator: (v) => validateRange(context, v, 50, 250),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [decimalOnly],
                  decoration: InputDecoration(
                    labelText: context.tr(
                      uz: 'Vazn, kg',
                      ru: 'Вес, кг',
                      en: 'Weight, kg',
                    ),
                  ),
                  validator: (v) => validateRange(context, v, 20, 300),
                ),
              ),
            ],
          ),
          gap,
          BloodTypeField(
            value: _bloodType,
            onChanged: (v) => setState(() => _bloodType = v),
          ),
          gap,
          AllergiesField(controller: _allergies),
          if (_error != null) FormError(saveErrorText(context, _error!)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(context.tr(uz: 'Saqlash', ru: 'Сохранить', en: 'Save')),
          ),
        ],
      ),
    );
  }
}
