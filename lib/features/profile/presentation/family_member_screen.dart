import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../data/family_repository.dart';
import 'labels.dart';
import 'widgets/form_fields.dart';

/// Add ([memberId] null) or edit / delete a family member.
class FamilyMemberScreen extends ConsumerWidget {
  const FamilyMemberScreen({super.key, this.memberId});

  final String? memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = memberId == null
        ? context.tr(
            uz: 'Oila a’zosini qo‘shish',
            ru: 'Добавить члена семьи',
            en: 'Add family member',
          )
        : context.tr(uz: 'Oila a’zosi', ru: 'Член семьи', en: 'Family member');
    if (memberId == null) {
      return AppScaffold(title: title, body: const _MemberForm());
    }
    final family = ref.watch(familyMembersProvider);
    return family.when(
      skipLoadingOnReload: true,
      loading: () => AppScaffold(
        title: title,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: title,
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(familyMembersProvider),
        ),
      ),
      data: (list) {
        final member = list.where((m) => m.id == memberId).firstOrNull;
        if (member == null) {
          return AppScaffold(
            title: title,
            body: EmptyState(
              emoji: '🔍',
              title: context.tr(
                uz: 'Topilmadi',
                ru: 'Не найдено',
                en: 'Not found',
              ),
            ),
          );
        }
        return AppScaffold(
          title: title,
          actions: [
            IconButton(
              tooltip: context.tr(uz: 'O‘chirish', ru: 'Удалить', en: 'Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, member),
            ),
          ],
          body: _MemberForm(member: member),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          dialog.tr(
            uz: '${member.name}ni o‘chirasizmi?',
            ru: 'Удалить ${member.name}?',
            en: 'Delete ${member.name}?',
          ),
        ),
        content: Text(
          dialog.tr(
            uz: 'Uning tibbiy karta yozuvlari ham o‘chadi.',
            ru: 'Его записи в медкарте тоже удалятся.',
            en: 'Their medical records will be deleted too.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(
              dialog.tr(uz: 'Bekor qilish', ru: 'Отмена', en: 'Cancel'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              dialog.tr(uz: 'O‘chirish', ru: 'Удалить', en: 'Delete'),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(familyRepositoryProvider).remove(member.id);
      if (context.mounted) context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              uz: 'O‘chirib bo‘lmadi. Qayta urinib ko‘ring.',
              ru: 'Не удалось удалить. Попробуйте снова.',
              en: 'Could not delete. Try again.',
            ),
          ),
        ),
      );
    }
  }
}

class _MemberForm extends ConsumerStatefulWidget {
  const _MemberForm({this.member});

  final FamilyMember? member;

  @override
  ConsumerState<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends ConsumerState<_MemberForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.member?.name ?? '');
  late final _year = TextEditingController(
    text: widget.member?.birthYear?.toString() ?? '',
  );
  late final _allergies = TextEditingController(
    text: widget.member?.allergies.join(', ') ?? '',
  );
  late final _phone = TextEditingController(text: widget.member?.phone ?? '');
  late String? _relation = widget.member?.relation;
  late String? _bloodType = widget.member?.bloodType;
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _allergies.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final year = _year.text.trim();
    final member = FamilyMember(
      id: widget.member?.id ?? '',
      name: _name.text.trim(),
      relation: _relation!,
      birthYear: year.isEmpty ? null : int.parse(year),
      bloodType: _bloodType,
      allergies: parseAllergies(_allergies.text),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    );
    final repo = ref.read(familyRepositoryProvider);
    try {
      await (widget.member == null ? repo.add(member) : repo.update(member));
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
    final relationOptions = [
      ...relations,
      if (_relation != null && !relations.contains(_relation)) _relation!,
    ];
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
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _relation,
            decoration: InputDecoration(
              labelText: context.tr(
                uz: 'Kim bo‘ladi',
                ru: 'Кем приходится',
                en: 'Relation',
              ),
              prefixIcon: const Icon(Icons.family_restroom),
            ),
            items: [
              for (final r in relationOptions)
                DropdownMenuItem(
                  value: r,
                  child: Text(relationLabel(context, r)),
                ),
            ],
            onChanged: (v) => setState(() => _relation = v),
            validator: (v) => v == null
                ? context.tr(uz: 'Tanlang', ru: 'Выберите', en: 'Choose one')
                : null,
          ),
          gap,
          TextFormField(
            controller: _year,
            keyboardType: TextInputType.number,
            inputFormatters: [digitsOnly],
            decoration: InputDecoration(
              labelText: context.tr(
                uz: 'Tug‘ilgan yil (ixtiyoriy)',
                ru: 'Год рождения (необязательно)',
                en: 'Birth year (optional)',
              ),
              prefixIcon: const Icon(Icons.cake_outlined),
            ),
            validator: (v) => validateBirthYear(context, v, required: false),
          ),
          gap,
          TextFormField(
            key: const ValueKey('member-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
            ],
            decoration: InputDecoration(
              labelText: context.tr(
                uz: 'Telefon (ixtiyoriy)',
                ru: 'Телефон (необязательно)',
                en: 'Phone (optional)',
              ),
              hintText: '+998 90 123 45 67',
              helperText: context.tr(
                uz: 'Dori ichilmasa, «Oila» ekranidan qo‘ng‘iroq qilasiz',
                ru: 'Если лекарство пропущено — позвоните с экрана «Семья»',
                en: 'Call from the Family screen when a dose is missed',
              ),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              return digits.isEmpty ||
                      (digits.length >= 7 && digits.length <= 15)
                  ? null
                  : context.tr(
                      uz: 'Telefon raqami noto‘g‘ri',
                      ru: 'Неверный номер телефона',
                      en: 'Invalid phone number',
                    );
            },
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
