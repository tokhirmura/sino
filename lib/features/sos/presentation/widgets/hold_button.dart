import 'package:flutter/material.dart';

import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';

/// Big red circle: hold for [duration] to confirm (no accidental SOS).
/// Releasing early resets the ring.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.onConfirmed,
    this.duration = const Duration(seconds: 2),
    this.size = 190,
    this.enabled = true,
  });

  final VoidCallback onConfirmed;
  final Duration duration;
  final double size;
  final bool enabled;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      widget.onConfirmed();
      _controller.reset();
    }
  }

  void _start() {
    if (widget.enabled) _controller.forward(from: 0);
  }

  void _cancel() {
    if (_controller.isAnimating) {
      _controller.animateBack(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final label = context.tr(
      uz: 'SOS — 2 soniya bosib turing',
      ru: 'SOS — удерживайте 2 секунды',
      en: 'SOS — hold for 2 seconds',
    );
    return Semantics(
      button: true,
      label: label,
      // Screen readers: a double-tap-and-hold is awkward, so a tap counts.
      onTap: widget.enabled ? widget.onConfirmed : null,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _cancel(),
        onPointerCancel: (_) => _cancel(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final v = _controller.value;
            return SizedBox.square(
              dimension: size + 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: size + 24,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 8,
                      color: AppColors.danger,
                      backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                    ),
                  ),
                  AnimatedScale(
                    scale: v > 0 ? 0.94 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      key: const ValueKey('sos-hold-button'),
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.enabled
                            ? AppColors.danger
                            : AppColors.danger.withValues(alpha: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.danger.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              context.tr(
                                uz: 'Bosib turing',
                                ru: 'Удерживайте',
                                en: 'Hold',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
