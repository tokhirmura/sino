import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend.dart';
import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/goal_picker.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/setup_prefill.dart';
import 'widgets/common.dart';

/// `/profile-setup`: first-run questionnaire. Step 1 — the main goal
/// (optional, «Keyinroq» skips); step 2 — name, birth year, height,
/// weight → `profiles`. The router keeps the user here while the profile
/// is incomplete and moves to home as soon as it is saved.
class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return AppScaffold(
      title: context.tr(
        uz: 'Profilingiz',
        ru: 'Ваш профиль',
        en: 'Your profile',
      ),
      actions: [
        TextButton(
          onPressed: () => signOut(ref),
          child: Text(context.tr(uz: 'Chiqish', ru: 'Выйти', en: 'Sign out')),
        ),
      ],
      body: user.when(
        // Keep the form (and its input) while the profile reloads.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (profile) => _SetupForm(profile: profile),
      ),
    );
  }
}

class _SetupForm extends ConsumerStatefulWidget {
  const _SetupForm({required this.profile});

  /// Null only if the DB row is missing — saving upserts it.
  final UserProfile? profile;

  @override
  ConsumerState<_SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends ConsumerState<_SetupForm> {
  static const _minYear = 1900;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _year;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final bool _fromOneId;

  /// Chosen goal; asked first unless the profile already has one.
  HealthGoal? _goal;
  late bool _askGoal;

  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    final prefill = ref.read(setupPrefillProvider);
    final name = (p?.fullName.trim().isNotEmpty ?? false)
        ? p!.fullName
        : prefill?.fullName ?? '';
    final year = p?.birthYear ?? prefill?.birthYear;
    _fromOneId =
        prefill != null &&
        (name == prefill.fullName || year == prefill.birthYear);
    _name = TextEditingController(text: name);
    _year = TextEditingController(text: year?.toString() ?? '');
    _height = TextEditingController(text: _num(p?.heightCm));
    _weight = TextEditingController(text: _num(p?.weightKg));
    _goal = p?.goal;
    _askGoal = _goal == null;
  }

  static String _num(double? v) => v == null
      ? ''
      : v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toString();

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final lang = context.lang.name;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final base =
          widget.profile ??
          UserProfile(
            id: ref.read(supabaseClientProvider).auth.currentUser!.id,
            fullName: '',
          );
      await ref
          .read(profileRepositoryProvider)
          .save(
            base.copyWith(
              fullName: _name.text.trim(),
              birthYear: int.parse(_year.text.trim()),
              heightCm: _parse(_height.text),
              weightKg: _parse(_weight.text),
              lang: lang,
              goal: _goal,
            ),
          );
      // Profile is complete → the router moves to home.
      await ref.read(setupPrefillProvider.notifier).clear();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _range(String? v, num min, num max, String Function() message) {
    final n = _parse(v ?? '');
    return n == null || n < min || n > max ? message() : null;
  }

  String _errorText(Object e) => e is SocketException || e is TimeoutException
      ? context.tr(
          uz: 'Internet aloqasi yo‘q. Tarmoqni tekshirib, qayta urinib ko‘ring.',
          ru: 'Нет связи с интернетом. Проверьте сеть и попробуйте снова.',
          en: 'No internet connection. Check your network and try again.',
        )
      : context.tr(
          uz: 'Saqlab bo‘lmadi. Qayta urinib ko‘ring.',
          ru: 'Не удалось сохранить. Попробуйте ещё раз.',
          en: 'Could not save. Please try again.',
        );

  Widget _goalStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const ValueKey('goal-step'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          context.tr(
            uz: 'Asosiy maqsadingiz nima?',
            ru: 'Какая у вас главная цель?',
            en: 'What is your main goal?',
          ),
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(
            uz:
                'Bosh sahifa shunga moslashadi. Keyin profilda o‘zgartirish '
                'mumkin.',
            ru: 'Главная подстроится под неё. Изменить можно в профиле.',
            en: 'Home adapts to it. You can change it in your profile.',
          ),
          style: text.bodyLarge,
        ),
        const SizedBox(height: 20),
        GoalPicker(value: _goal, onChanged: (g) => setState(() => _goal = g)),
        const SizedBox(height: 24),
        PrimaryButton(
          key: const ValueKey('goal-next'),
          label: context.tr(uz: 'Davom etish', ru: 'Далее', en: 'Continue'),
          icon: Icons.arrow_forward_rounded,
          onPressed: _goal == null
              ? null
              : () => setState(() => _askGoal = false),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => setState(() {
            _goal = null;
            _askGoal = false;
          }),
          child: Text(context.tr(uz: 'Keyinroq', ru: 'Позже', en: 'Later')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    child: _askGoal ? _goalStep(context) : _form(context),
  );

  Widget _form(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final thisYear = DateTime.now().year;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('form-step'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_goal != null) ...[
            Row(
              children: [
                Flexible(
                  child: Pill(
                    '${_goal!.emoji} ${_goal!.title(context.lang)}',
                    key: const ValueKey('chosen-goal'),
                    wrap: true,
                  ),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _askGoal = true),
                  child: Text(
                    context.tr(
                      uz: 'O‘zgartirish',
                      ru: 'Изменить',
                      en: 'Change',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            context.tr(
              uz:
                  'Bir daqiqa: bu ma’lumotlar bilan ovqatlanish, mashg‘ulot va '
                  'salomatlik tavsiyalari sizga moslashadi.',
              ru:
                  'Одна минута: по этим данным мы подстроим питание, '
                  'тренировки и советы под вас.',
              en:
                  'One minute: we use this to tailor nutrition, workouts and '
                  'health tips to you.',
            ),
            style: text.bodyLarge,
          ),
          if (_fromOneId) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.verified, size: 18, color: AppColors.good),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr(
                      uz: 'Ism va tug‘ilgan yil OneID’dan olindi',
                      ru: 'Имя и год рождения взяты из OneID',
                      en: 'Name and birth year taken from OneID',
                    ),
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: context.tr(uz: 'Ism', ru: 'Имя', en: 'Name'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (v) => (v ?? '').trim().length >= 2
                ? null
                : context.tr(
                    uz: 'Ismingizni kiriting',
                    ru: 'Введите имя',
                    en: 'Enter your name',
                  ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _year,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.tr(
                uz: 'Tug‘ilgan yil',
                ru: 'Год рождения',
                en: 'Birth year',
              ),
              hintText: '1995',
              prefixIcon: const Icon(Icons.cake_outlined),
            ),
            validator: (v) => _range(
              v,
              _minYear,
              thisYear,
              () => context.tr(
                uz: '$_minYear–$thisYear oralig‘idagi yil',
                ru: 'Год от $_minYear до $thisYear',
                en: 'A year from $_minYear to $thisYear',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _height,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: decimal,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr(uz: 'Bo‘y', ru: 'Рост', en: 'Height'),
                    suffixText: context.tr(uz: 'sm', ru: 'см', en: 'cm'),
                    prefixIcon: const Icon(Icons.height),
                  ),
                  validator: (v) => _range(
                    v,
                    50,
                    250,
                    () => context.tr(
                      uz: '50–250 sm',
                      ru: '50–250 см',
                      en: '50–250 cm',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _weight,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: decimal,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: context.tr(uz: 'Vazn', ru: 'Вес', en: 'Weight'),
                    suffixText: context.tr(uz: 'kg', ru: 'кг', en: 'kg'),
                    prefixIcon: const Icon(Icons.monitor_weight_outlined),
                  ),
                  validator: (v) => _range(
                    v,
                    20,
                    300,
                    () => context.tr(
                      uz: '20–300 kg',
                      ru: '20–300 кг',
                      en: '20–300 kg',
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            InlineMessage.error(_errorText(_error!)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const ButtonSpinner()
                : Text(context.tr(uz: 'Saqlash', ru: 'Сохранить', en: 'Save')),
          ),
        ],
      ),
    );
  }
}
