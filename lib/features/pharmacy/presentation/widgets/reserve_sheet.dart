import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/user.dart';
import '../../../../core/l10n/app_lang.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/money.dart';
import '../../application/pharmacy_providers.dart';
import '../../data/models.dart';
import '../../data/rx_photo.dart';
import '../labels.dart';
import 'common.dart';

/// Reservation sheet: for whom, prescription photo (required for `rx`),
/// summary and confirm. Returns the saved reservation, `null` if closed.
Future<Reservation?> showReserveSheet(BuildContext context, StockOffer offer) =>
    showModalBottomSheet<Reservation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ReserveSheet(offer: offer),
    );

class ReserveSheet extends ConsumerStatefulWidget {
  const ReserveSheet({super.key, required this.offer});

  final StockOffer offer;

  @override
  ConsumerState<ReserveSheet> createState() => _ReserveSheetState();
}

class _ReserveSheetState extends ConsumerState<ReserveSheet> {
  String? _memberId;
  String? _photo;
  bool _saving = false;
  String? _error;

  StockOffer get _offer => widget.offer;

  Future<void> _pick(RxPhotoSource source) async {
    try {
      final path = await ref.read(rxPhotoPickerProvider).pick(source);
      if (path != null && mounted) {
        setState(() {
          _photo = path;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.tr(
            uz: 'Kamera yoki galereyani ochib bo‘lmadi.',
            ru: 'Не удалось открыть камеру или галерею.',
            en: 'Couldn’t open the camera or gallery.',
          ),
        );
      }
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(reservationsProvider.notifier)
          .reserve(_offer, forMemberId: _memberId, rxAttached: _photo != null);
      if (_photo != null) {
        await ref.read(rxPhotosProvider.notifier).save(saved.id, _photo!);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = reservationProblemText(context, e) ?? errorMessage(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    // Keep the live list running while the sheet is open (Riverpod pauses
    // unlistened providers; `reserve` waits for the first load).
    ref.watch(reservationsProvider);
    final members = ref.watch(familyMembersProvider).value ?? const [];
    final m = _offer.medicine;
    final p = _offer.pharmacy;
    final needsPhoto = m.rx && _photo == null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr(
              uz: 'Bron qilish',
              ru: 'Бронирование',
              en: 'Reservation',
            ),
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: Icons.medication_rounded,
            title: m.name,
            subtitle: formLabel(context, m.form),
          ),
          _SummaryRow(
            icon: Icons.local_pharmacy_rounded,
            title: p.name,
            subtitle: [
              if (p.address != null) p.address!,
              hoursLabel(context, p),
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(uz: 'Kim uchun', ru: 'Для кого', en: 'For whom'),
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(context.tr(uz: 'O‘zim', ru: 'Себе', en: 'Me')),
                selected: _memberId == null,
                onSelected: (_) => setState(() => _memberId = null),
              ),
              for (final f in members)
                ChoiceChip(
                  label: Text(f.name),
                  selected: _memberId == f.id,
                  onSelected: (_) => setState(() => _memberId = f.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            m.rx
                ? context.tr(
                    uz: 'Retsept rasmi (majburiy)',
                    ru: 'Фото рецепта (обязательно)',
                    en: 'Prescription photo (required)',
                  )
                : context.tr(
                    uz: 'Retsept rasmi (ixtiyoriy)',
                    ru: 'Фото рецепта (необязательно)',
                    en: 'Prescription photo (optional)',
                  ),
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(
              uz: 'Rasm faqat telefoningizda saqlanadi.',
              ru: 'Фото хранится только на вашем телефоне.',
              en: 'The photo stays on your phone only.',
            ),
            style: text.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (_photo != null)
            Row(
              children: [
                RxThumbnail(path: _photo!, size: 72),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(
                      uz: 'Retsept biriktirildi',
                      ru: 'Рецепт прикреплён',
                      en: 'Prescription attached',
                    ),
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.readable(
                        AppColors.good,
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr(
                    uz: 'Olib tashlash',
                    ru: 'Убрать',
                    en: 'Remove',
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => setState(() => _photo = null),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(RxPhotoSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      context.tr(uz: 'Kamera', ru: 'Камера', en: 'Camera'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(RxPhotoSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      context.tr(uz: 'Galereya', ru: 'Галерея', en: 'Gallery'),
                    ),
                  ),
                ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            context.tr(
              uz:
                  'To‘lov dorixonada, dorini olayotganda. Bron dorixona '
                  'tasdiqlagach tayyor bo‘ladi.',
              ru:
                  'Оплата в аптеке при получении. Бронь будет готова, когда '
                  'аптека её соберёт.',
              en:
                  'Pay at the pharmacy on pickup. The reservation is ready '
                  'once the pharmacy prepares it.',
            ),
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving || needsPhoto ? null : _confirm,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(
                    context.tr(
                      uz: 'Bron qilish · ${formatMoney(_offer.priceUzs)}',
                      ru: 'Забронировать · ${formatMoney(_offer.priceUzs)}',
                      en: 'Reserve · ${formatMoney(_offer.priceUzs)}',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.readable(
              AppColors.primary,
              Theme.of(context).brightness,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Local prescription photo; a placeholder when the file is gone.
class RxThumbnail extends StatelessWidget {
  const RxThumbnail({super.key, required this.path, this.size = 56});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.receipt_long_rounded, color: scheme.onSurfaceVariant),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder(),
        ),
      ),
    );
  }
}
