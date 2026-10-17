import 'package:flutter/widgets.dart';

import 'holidays.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'x_archive/x_archive.dart';

export 'l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// 日付の書式に使うロケール（例: ja, en）。
  String get localeName => l10n.localeName;
}

/// 予定の持ち主の名前（「みんな」「いなくなった人」を言語に合わせる）。
String ownerName(BuildContext context, Family family, String ownerId) =>
    family.nameOf(
      ownerId,
      everyone: context.l10n.everyone,
      gone: context.l10n.formerMember,
    );

String xKindLabel(BuildContext context, XPostKind kind) => switch (kind) {
  XPostKind.post => context.l10n.xKindPost,
  XPostKind.reply => context.l10n.xKindReply,
  XPostKind.repost => context.l10n.xKindRepost,
  XPostKind.like => context.l10n.xKindLike,
};

/// 日本の祝日を表示するか。日本語を使っている人、または日本にいる人に表示する。
bool showsJapaneseHolidays(BuildContext context) {
  if (Localizations.localeOf(context).languageCode == 'ja') return true;
  return View.of(context).platformDispatcher.locales
      .any((l) => l.countryCode == 'JP' || l.languageCode == 'ja');
}

/// 日本の祝日の英語名（内閣府の英語表記に合わせる）。
const holidayNamesEn = {
  '元日': "New Year's Day",
  '成人の日': 'Coming of Age Day',
  '建国記念の日': 'National Foundation Day',
  '天皇誕生日': "Emperor's Birthday",
  '春分の日': 'Vernal Equinox Day',
  '昭和の日': 'Showa Day',
  'みどりの日': 'Greenery Day',
  '憲法記念日': 'Constitution Memorial Day',
  'こどもの日': "Children's Day",
  '海の日': 'Marine Day',
  '山の日': 'Mountain Day',
  '敬老の日': 'Respect for the Aged Day',
  '秋分の日': 'Autumnal Equinox Day',
  '体育の日': 'Health and Sports Day',
  'スポーツの日': 'Sports Day',
  '文化の日': 'Culture Day',
  '勤労感謝の日': 'Labor Thanksgiving Day',
  '振替休日': 'Substitute Holiday',
  '国民の休日': "Citizens' Holiday",
  '昭和天皇の大喪の礼': 'Funeral of Emperor Showa',
  '即位礼正殿の儀': 'Enthronement Ceremony',
  '皇太子徳仁親王の結婚の儀': 'Wedding of Crown Prince Naruhito',
  '天皇の即位の日': "Emperor's Accession Day",
};

/// 画面に出す祝日名。表示しない設定・祝日でない日は null。
String? localizedHolidayName(BuildContext context, DateTime day) {
  if (!showsJapaneseHolidays(context)) return null;
  final name = holidayName(day);
  if (name == null) return null;
  if (Localizations.localeOf(context).languageCode == 'ja') return name;
  return holidayNamesEn[name] ?? name;
}
