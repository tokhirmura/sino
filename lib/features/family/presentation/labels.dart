import 'package:flutter/widgets.dart';

import '../../../core/data/user.dart';
import '../../../core/l10n/app_lang.dart';

/// `family_members.relation` is stored in Uzbek (see the profile feature).
String relationEmoji(String relation) => switch (relation) {
  'ona' => '👩',
  'ota' => '👨',
  'qizi' => '👧',
  'o‘g‘li' => '👦',
  'buvi' => '👵',
  'bobo' => '👴',
  'turmush o‘rtog‘i' => '💞',
  'opa-singil' => '👩',
  'aka-uka' => '🧑',
  _ => '🧑',
};

String relationText(BuildContext c, String relation) => switch (relation) {
  'ona' => c.tr(uz: 'Ona', ru: 'Мама', en: 'Mother'),
  'ota' => c.tr(uz: 'Ota', ru: 'Папа', en: 'Father'),
  'turmush o‘rtog‘i' => c.tr(
    uz: 'Turmush o‘rtog‘i',
    ru: 'Супруг(а)',
    en: 'Spouse',
  ),
  'o‘g‘li' => c.tr(uz: 'O‘g‘li', ru: 'Сын', en: 'Son'),
  'qizi' => c.tr(uz: 'Qizi', ru: 'Дочь', en: 'Daughter'),
  'aka-uka' => c.tr(uz: 'Aka-uka', ru: 'Брат', en: 'Brother'),
  'opa-singil' => c.tr(uz: 'Opa-singil', ru: 'Сестра', en: 'Sister'),
  'buvi' => c.tr(uz: 'Buvi', ru: 'Бабушка', en: 'Grandmother'),
  'bobo' => c.tr(uz: 'Bobo', ru: 'Дедушка', en: 'Grandfather'),
  _ => c.tr(uz: 'Oila a’zosi', ru: 'Член семьи', en: 'Family member'),
};

/// Uzbek «my …» for the alert: «Onam dorini ichmadi».
String? _myRelationUz(String relation) => switch (relation) {
  'ona' => 'Onam',
  'ota' => 'Otam',
  'qizi' => 'Qizim',
  'o‘g‘li' => 'O‘g‘lim',
  'buvi' => 'Buvim',
  'bobo' => 'Bobom',
  'turmush o‘rtog‘i' => 'Turmush o‘rtog‘im',
  'aka-uka' => 'Akam',
  'opa-singil' => 'Opam',
  _ => null,
};

/// «Onam dorini ichmadi» / «Dilfuza: лекарство не принято» /
/// «Mom missed a dose».
String missedText(BuildContext c, FamilyMember m) {
  final en = switch (m.relation) {
    'ona' => 'Mom',
    'ota' => 'Dad',
    'buvi' => 'Grandma',
    'bobo' => 'Grandpa',
    _ => m.name,
  };
  return c.tr(
    uz: '${_myRelationUz(m.relation) ?? m.name} dorini ichmadi',
    ru: '${m.name}: лекарство не принято',
    en: '$en missed a dose',
  );
}

/// «08:30».
String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
