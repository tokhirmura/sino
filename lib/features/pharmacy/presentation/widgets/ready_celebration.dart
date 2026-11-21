import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../application/ready_celebrations.dart';
import '../../data/external_launcher.dart';
import '../../data/models.dart';
import 'common.dart';

/// Wrap a screen (or home card) with it: when a reservation becomes ready,
/// shows [showReadyCelebration]. Several hosts may be mounted — each
/// transition is shown once.
class ReadyCelebrationHost extends ConsumerWidget {
  const ReadyCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(readyCelebrationsProvider, (_, queue) {
      if (queue.isEmpty) return;
      // After the frame: the first host to run takes it, the others see an
      // empty queue (no state change while listeners are notified).
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final r = ref.read(readyCelebrationsProvider.notifier).take();
        if (r != null) showReadyCelebration(context, r);
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    });
    return child;
  }
}

/// Full-screen «Bron tayyor!» banner: confetti, a bouncing check, haptic
/// feedback, directions to the pharmacy.
Future<void> showReadyCelebration(BuildContext context, Reservation r) {
  HapticFeedback.heavyImpact();
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: AppMotion.medium,
    pageBuilder: (_, _, _) => ReadyCelebration(reservation: r),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class ReadyCelebration extends ConsumerStatefulWidget {
  const ReadyCelebration({super.key, required this.reservation});

  final Reservation reservation;

  @override
  ConsumerState<ReadyCelebration> createState() => _ReadyCelebrationState();
}

class _ReadyCelebrationState extends ConsumerState<ReadyCelebration> {
  final _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1600),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _confetti.play();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _directions(Pharmacy p) async {
    final ok = await ref.read(pharmacyLauncherProvider)(pharmacyMapsUri(p));
    if (!ok && mounted) {
      showPharmacySnack(
        context,
        context.tr(
          uz: 'Xaritani ochib bo‘lmadi',
          ru: 'Не удалось открыть карту',
          en: 'Couldn’t open the map',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = widget.reservation;
    final p = r.pharmacy;
    final name = r.medicine?.name ?? '';
    final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const white = Colors.white;

    Widget check = Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: white,
        boxShadow: AppShadows.glow(AppColors.good),
      ),
      child: const Icon(Icons.check_rounded, size: 72, color: AppColors.good),
    );
    if (!calm) {
      check = check
          .animate()
          .scale(
            begin: const Offset(0.3, 0.3),
            duration: 650.ms,
            curve: Curves.elasticOut,
          )
          .then(delay: 150.ms)
          .shimmer(duration: 900.ms, color: AppColors.saffron);
    }

    return Material(
      key: const ValueKey('reservation-ready-celebration'),
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GradientBackdrop(
              bottomRadius: 0,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          check,
                          const SizedBox(height: 28),
                          Text(
                            context.tr(
                              uz: 'Bron tayyor! 🎉',
                              ru: 'Бронь готова! 🎉',
                              en: 'Your order is ready! 🎉',
                            ),
                            textAlign: TextAlign.center,
                            style: text.headlineMedium?.copyWith(
                              color: white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.tr(
                              uz: '$name olib ketishga tayyor!',
                              ru: '$name готово к выдаче!',
                              en: '$name is ready for pickup!',
                            ),
                            textAlign: TextAlign.center,
                            style: text.titleMedium?.copyWith(color: white),
                          ),
                          if (p != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.input,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.local_pharmacy_rounded,
                                    color: white,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: text.titleSmall?.copyWith(
                                            color: white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (p.address != null)
                                          Text(
                                            p.address!,
                                            style: text.bodySmall?.copyWith(
                                              color: white.withValues(
                                                alpha: 0.9,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            context.tr(
                              uz:
                                  'Dorixonaga boring va bron haqida ayting. '
                                  'To‘lov joyida.',
                              ru:
                                  'Приходите в аптеку и назовите бронь. '
                                  'Оплата на месте.',
                              en:
                                  'Go to the pharmacy and mention your '
                                  'reservation. Pay there.',
                            ),
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (p != null)
                            PrimaryButton(
                              label: context.tr(
                                uz: 'Yo‘nalish',
                                ru: 'Маршрут',
                                en: 'Directions',
                              ),
                              icon: Icons.directions_rounded,
                              gradient: AppColors.saffronGradient,
                              onPressed: () => _directions(p),
                            ),
                          const SizedBox(height: 8),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: white),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              context.tr(
                                uz: 'Ajoyib!',
                                ru: 'Отлично!',
                                en: 'Great!',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              maxBlastForce: 28,
              minBlastForce: 10,
              gravity: 0.25,
              colors: const [
                AppColors.saffron,
                AppColors.turquoise,
                AppColors.coral,
                AppColors.violet,
                AppColors.good,
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
