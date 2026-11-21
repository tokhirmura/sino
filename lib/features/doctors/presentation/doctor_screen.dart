import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/emoji_box.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../application/doctor_slots.dart';
import '../application/doctors_providers.dart';
import '../data/models.dart';
import 'doctors_paths.dart';
import 'labels.dart';
import 'widgets.dart';

/// `/doctors/:id`: the doctor, then day → slot → person → clinic / online
/// → book.
class DoctorScreen extends ConsumerWidget {
  const DoctorScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: context.tr(uz: 'Shifokor', ru: 'Врач', en: 'Doctor'),
      padding: EdgeInsets.zero,
      body: AsyncValueView(
        value: ref.watch(doctorsByIdProvider),
        onRetry: () => ref.invalidate(doctorsCatalogProvider),
        data: (byId) {
          final d = byId[doctorId];
          if (d == null) {
            return EmptyState(
              emoji: '🔍',
              title: context.tr(
                uz: 'Shifokor topilmadi',
                ru: 'Врач не найден',
                en: 'Doctor not found',
              ),
            );
          }
          return _Booking(doctor: d);
        },
      ),
    );
  }
}

class _Booking extends ConsumerStatefulWidget {
  const _Booking({required this.doctor});

  final Doctor doctor;

  @override
  ConsumerState<_Booking> createState() => _BookingState();
}

class _BookingState extends ConsumerState<_Booking> {
  DateTime _now() => ref.read(doctorsClockProvider)();
  late final List<DateTime> _days = bookingDays(_now());
  // Today only while it still has slots ahead (evening → tomorrow).
  late DateTime? _day = _days
      .where((d) => daySlotTimes(d).any((t) => t.isAfter(_now())))
      .followedBy(_days)
      .firstOrNull;
  DateTime? _slot;
  String? _memberId;
  bool _online = false;
  bool _saving = false;

  Future<void> _book() async {
    final slot = _slot;
    if (slot == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(appointmentsProvider.notifier)
          .book(widget.doctor, slot, memberId: _memberId, online: _online);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _slot = null;
      });
      final now = _now();
      showDoctorsSnack(
        context,
        context.tr(
          uz: 'Qabulga yozildingiz: ${appointmentWhen(context, slot, now)}',
          ru: 'Вы записаны: ${appointmentWhen(context, slot, now)}',
          en: 'Booked: ${appointmentWhen(context, slot, now)}',
        ),
        action: SnackBarAction(
          label: context.tr(uz: 'Yozuvlarim', ru: 'Мои записи', en: 'My list'),
          onPressed: () => context.push(DoctorsPaths.appointments),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _slot = null;
      });
      showDoctorsSnack(context, appointmentErrorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final d = widget.doctor;
    final members = ref.watch(familyMembersProvider).value ?? const [];
    final now = ref.watch(doctorsClockProvider)();
    final day = _day;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Header(doctor: d),
        const SizedBox(height: 12),
        const DoctorsDisclaimer(),
        const SizedBox(height: 16),
        SectionTitle(
          context.tr(uz: 'Kim uchun', ru: 'Для кого', en: 'For whom'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: Text(context.tr(uz: 'O‘zim', ru: 'Для себя', en: 'Me')),
              selected: _memberId == null,
              onSelected: (_) => setState(() {
                _memberId = null;
                _slot = null;
              }),
            ),
            for (final m in members)
              ChoiceChip(
                label: Text(m.name),
                selected: _memberId == m.id,
                onSelected: (_) => setState(() {
                  _memberId = m.id;
                  _slot = null;
                }),
              ),
          ],
        ),
        if (d.online) ...[
          const SizedBox(height: 16),
          SectionTitle(
            context.tr(uz: 'Qabul turi', ru: 'Формат', en: 'Visit type'),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.local_hospital_rounded),
                label: Text(
                  context.tr(uz: 'Klinikada', ru: 'В клинике', en: 'In clinic'),
                ),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.videocam_rounded),
                label: Text(
                  context.tr(uz: 'Onlayn', ru: 'Онлайн', en: 'Online'),
                ),
              ),
            ],
            selected: {_online},
            onSelectionChanged: (s) => setState(() => _online = s.first),
          ),
        ],
        const SizedBox(height: 16),
        SectionTitle(context.tr(uz: 'Kun', ru: 'День', en: 'Day')),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final dd in _days) ...[
                ChoiceChip(
                  label: Text(dayLabel(context, dd, now)),
                  selected: dd == day,
                  onSelected: (_) => setState(() {
                    _day = dd;
                    _slot = null;
                  }),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(context.tr(uz: 'Vaqt', ru: 'Время', en: 'Time')),
        const SizedBox(height: 8),
        if (day != null)
          AsyncValueView(
            value: ref.watch(
              doctorSlotsProvider((
                doctorId: d.id,
                day: day,
                memberId: _memberId,
              )),
            ),
            compact: true,
            onRetry: () => ref.invalidate(appointmentsProvider),
            data: (slots) => _SlotGrid(
              slots: slots,
              selected: _slot,
              onSelect: (s) => setState(() => _slot = s),
            ),
          ),
        const SizedBox(height: 8),
        const _SlotLegend(),
        const SizedBox(height: 20),
        PrimaryButton(
          key: const ValueKey('book-appointment'),
          onPressed: _slot == null ? null : _book,
          loading: _saving,
          icon: Icons.event_available_rounded,
          label: _slot == null
              ? context.tr(
                  uz: 'Vaqtni tanlang',
                  ru: 'Выберите время',
                  en: 'Pick a time',
                )
              : context.tr(
                  uz: 'Yozilish · ${appointmentWhen(context, _slot!, now)}',
                  ru: 'Записаться · ${appointmentWhen(context, _slot!, now)}',
                  en: 'Book · ${appointmentWhen(context, _slot!, now)}',
                ),
        ),
        if (_slot != null && !d.isFree && d.priceUzs != null) ...[
          const SizedBox(height: 6),
          Center(
            child: DefaultTextStyle.merge(
              style: text.bodySmall,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr(
                      uz: 'Klinikada to‘lanadi: ',
                      ru: 'Оплата в клинике: ',
                      en: 'Paid at the clinic: ',
                    ),
                  ),
                  DoctorPrice(doctor: d, style: text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final d = doctor;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmojiBox(
            emoji: specialtyEmoji(d.specialty),
            color: specialtyColor(d.specialty),
            size: 60,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  specialtyLabel(context, d.specialty),
                  style: text.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (d.clinic != null)
                  Text(
                    d.clinic!,
                    style: text.bodySmall?.copyWith(color: muted),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (d.rating != null)
                      Tag(
                        d.rating!.toStringAsFixed(1),
                        color: AppColors.amber,
                        icon: Icons.star_rounded,
                      ),
                    if (d.years != null)
                      Tag(yearsLabel(context, d.years!), color: AppColors.sky),
                    if (d.online)
                      Tag(
                        context.tr(uz: 'Onlayn', ru: 'Онлайн', en: 'Online'),
                        color: AppColors.sky,
                        icon: Icons.videocam_rounded,
                      ),
                    DoctorPrice(
                      doctor: d,
                      style: text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelect,
  });

  final List<Slot> slots;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Text(
        context.tr(uz: 'Dam olish kuni', ru: 'Выходной', en: 'Day off'),
      );
    }
    if (!slots.any((s) => s.isFree || s.state == SlotState.mine)) {
      return Text(
        context.tr(
          uz: 'Bu kunga bo‘sh vaqt qolmadi — boshqa kunni tanlang.',
          ru: 'Свободного времени нет — выберите другой день.',
          en: 'No free time left — pick another day.',
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in slots)
          if (s.state != SlotState.past)
            _SlotChip(slot: s, selected: s.at == selected, onSelect: onSelect),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onSelect,
  });

  final Slot slot;
  final bool selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final label = hhmm(slot.at);
    return switch (slot.state) {
      SlotState.free => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelect(slot.at),
      ),
      SlotState.mine => Chip(
        avatar: const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: AppColors.good,
        ),
        label: Text(label),
        backgroundColor: AppColors.good.withValues(alpha: 0.14),
        side: BorderSide.none,
      ),
      _ => Tooltip(
        message: slot.state == SlotState.clash
            ? context.tr(
                uz: 'Shu vaqtda boshqa qabulingiz bor',
                ru: 'В это время у вас другая запись',
                en: 'You have another appointment then',
              )
            : context.tr(uz: 'Band', ru: 'Занято', en: 'Taken'),
        child: ChoiceChip(
          label: Text(
            label,
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
          selected: false,
          onSelected: null,
        ),
      ),
    };
  }
}

class _SlotLegend extends StatelessWidget {
  const _SlotLegend();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Text(
      context.tr(
        uz: 'Qabul 30 daqiqa. Chizilgan vaqtlar band, ✓ — sizning yozuvingiz.',
        ru: 'Приём 30 минут. Зачёркнутое время занято, ✓ — ваша запись.',
        en: 'Visits are 30 min. Crossed-out times are taken, ✓ is yours.',
      ),
      style: text,
    );
  }
}
