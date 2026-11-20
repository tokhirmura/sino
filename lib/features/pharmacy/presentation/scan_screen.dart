import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';

/// Barcode scanner. Pops with the scanned (or typed) code.
/// The camera may be unavailable (emulator, no permission) — the code can
/// always be typed instead.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.useCamera = true});

  /// `false` in tests (no camera plugin).
  final bool useCamera;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  MobileScannerController? _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.useCamera) {
      _controller = MobileScannerController(
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done || code.trim().isEmpty) return;
    _done = true;
    Navigator.of(context).pop(code.trim());
  }

  Future<void> _typeCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _CodeDialog(),
    );
    if (code != null && mounted) _finish(code);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          context.tr(uz: 'Skanerlash', ru: 'Сканирование', en: 'Scan'),
        ),
        actions: [
          if (controller != null)
            IconButton(
              tooltip: context.tr(uz: 'Chiroq', ru: 'Фонарик', en: 'Torch'),
              icon: const Icon(Icons.flashlight_on_rounded),
              onPressed: controller.toggleTorch,
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                for (final b in capture.barcodes) {
                  final v = b.rawValue;
                  if (v != null && v.isNotEmpty) {
                    _finish(v);
                    return;
                  }
                }
              },
              errorBuilder: (context, error) =>
                  _CameraUnavailable(onType: _typeCode),
            )
          else
            _CameraUnavailable(onType: _typeCode),
          if (controller != null)
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr(
                      uz: 'Qutidagi shtrix-kodni ramkaga to‘g‘rilang',
                      ru: 'Наведите рамку на штрих-код на упаковке',
                      en: 'Point the frame at the barcode on the box',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _typeCode,
                    icon: const Icon(Icons.keyboard_rounded),
                    label: Text(
                      context.tr(
                        uz: 'Kodni qo‘lda kiritish',
                        ru: 'Ввести код вручную',
                        en: 'Type the code',
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
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.onType});

  final VoidCallback onType;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white70,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              uz: 'Kamera mavjud emas. Kodni qo‘lda kiriting.',
              ru: 'Камера недоступна. Введите код вручную.',
              en: 'Camera unavailable. Type the code instead.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onType,
            child: Text(
              context.tr(uz: 'Kiritish', ru: 'Ввести', en: 'Enter'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Manual barcode entry; owns its controller (disposed after the closing
/// animation, not right after `pop`).
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      context.tr(
        uz: 'Shtrix-kodni kiriting',
        ru: 'Введите штрих-код',
        en: 'Enter the barcode',
      ),
    ),
    content: TextField(
      controller: _ctrl,
      autofocus: true,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(hintText: '4780000000000'),
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr(uz: 'Bekor', ru: 'Отмена', en: 'Cancel')),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_ctrl.text),
        child: Text(context.tr(uz: 'Qidirish', ru: 'Найти', en: 'Search')),
      ),
    ],
  );
}
