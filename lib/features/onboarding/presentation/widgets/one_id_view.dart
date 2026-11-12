import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/error_view.dart';
import '../../application/one_id_controller.dart';
import '../../data/one_id_provider.dart';
import '../auth_error_text.dart';
import 'common.dart';

/// OneID: biometrics (~2 s) → verified registry data → consent → session.
class OneIdView extends ConsumerWidget {
  const OneIdView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verification = ref.watch(oneIdVerificationProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepHeader(title: 'OneID', onBack: onBack),
          Expanded(
            child: verification.when(
              loading: () => const _BiometricScan(),
              error: (e, _) => ErrorView(
                error: authErrorText(context, e),
                onRetry: () => ref.invalidate(oneIdVerificationProvider),
              ),
              data: (profile) => _VerifiedProfile(profile: profile),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricScan extends StatefulWidget {
  const _BiometricScan();

  @override
  State<_BiometricScan> createState() => _BiometricScanState();
}

class _BiometricScanState extends State<_BiometricScan>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween(
              begin: 0.9,
              end: 1.08,
            ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.fingerprint,
                size: 88,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            context.tr(
              uz: 'Biometrik tekshiruv…',
              ru: 'Биометрическая проверка…',
              en: 'Biometric check…',
            ),
            style: text.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              uz: 'Ma’lumotlar davlat reyestridan olinmoqda',
              ru: 'Получаем данные из госреестра',
              en: 'Fetching data from the state registry',
            ),
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _VerifiedProfile extends ConsumerStatefulWidget {
  const _VerifiedProfile({required this.profile});

  final OneIdProfile profile;

  @override
  ConsumerState<_VerifiedProfile> createState() => _VerifiedProfileState();
}

class _VerifiedProfileState extends ConsumerState<_VerifiedProfile> {
  bool _consent = false;
  bool _loading = false;
  Object? _error;

  Future<void> _continue() async {
    final lang = context.lang.name;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Session appears → router leaves onboarding.
      await ref.read(oneIdAuthProvider).signIn(lang: lang);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.good.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppColors.cardRadius),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: AppColors.good, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(
                      uz: 'Profil davlat tomonidan tasdiqlangan',
                      ru: 'Профиль подтверждён государством',
                      en: 'Profile verified by the government',
                    ),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _Row(
                  icon: Icons.person_outline,
                  label: context.tr(uz: 'F.I.Sh.', ru: 'ФИО', en: 'Full name'),
                  value: p.fullName,
                ),
                _Row(
                  icon: Icons.badge_outlined,
                  label: context.tr(uz: 'JShShIR', ru: 'ПИНФЛ', en: 'PINFL'),
                  value: p.pinflMasked,
                ),
                _Row(
                  icon: Icons.cake_outlined,
                  label: context.tr(
                    uz: 'Tug‘ilgan sana',
                    ru: 'Дата рождения',
                    en: 'Date of birth',
                  ),
                  value: DateFormat('dd.MM.yyyy').format(p.birthDate),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              uz: 'Yuklangan ma’lumotlar',
              ru: 'Загруженные данные',
              en: 'Imported data',
            ),
            style: text.titleSmall,
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _Row(
                  icon: Icons.local_hospital_outlined,
                  label: context.tr(
                    uz: 'Poliklinika',
                    ru: 'Поликлиника',
                    en: 'Polyclinic',
                  ),
                  value: context.trMap(p.polyclinic),
                ),
                _Row(
                  icon: Icons.folder_shared_outlined,
                  label: context.tr(
                    uz: 'Tibbiy karta',
                    ru: 'Медкарта',
                    en: 'Medical record',
                  ),
                  value: context.tr(
                    uz: '${p.medicalRecords} ta yozuv',
                    ru: 'записей: ${p.medicalRecords}',
                    en: '${p.medicalRecords} entries',
                  ),
                ),
                _Row(
                  icon: Icons.receipt_long_outlined,
                  label: context.tr(
                    uz: 'Retseptlar',
                    ru: 'Рецепты',
                    en: 'Prescriptions',
                  ),
                  value: context.tr(
                    uz: '${p.prescriptions} ta faol',
                    ru: 'активных: ${p.prescriptions}',
                    en: '${p.prescriptions} active',
                  ),
                ),
                _Row(
                  icon: Icons.health_and_safety_outlined,
                  label: context.tr(
                    uz: 'Sug‘urta',
                    ru: 'Страховка',
                    en: 'Insurance',
                  ),
                  value: context.trMap(p.insurance),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _consent,
            onChanged: _loading
                ? null
                : (v) => setState(() => _consent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.tr(
                uz:
                    'Sino’ga tibbiy kartamdagi ma’lumotlardan foydalanishga '
                    'roziman',
                ru: 'Разрешаю Sino доступ к данным моей медкарты',
                en: 'I allow Sino to access my medical record',
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            InlineMessage.error(authErrorText(context, _error!)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _consent && !_loading ? _continue : null,
            child: _loading
                ? const ButtonSpinner()
                : Text(
                    context.tr(
                      uz: 'Davom etish',
                      ru: 'Продолжить',
                      en: 'Continue',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                Text(value, style: text.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
