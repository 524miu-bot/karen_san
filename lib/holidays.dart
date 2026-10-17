/// 日本の祝日（「国民の祝日に関する法律」による休日）を計算する。
///
/// 含めるのは法律で休日と定められた日だけ：
/// - 国民の祝日（元日、成人の日、…、勤労感謝の日）
/// - 振替休日（祝日が日曜日のとき）
/// - 国民の休日（祝日に挟まれた平日）
/// - 皇室行事などで特別に休日とされた日
///
/// 七五三・母の日・節分・クリスマスなどの「行事」は休日ではないので含めない。
///
/// 春分の日・秋分の日は毎年 2 月の官報で翌年分が正式に決まる。ここでは
/// 国立天文台の計算に基づく一般的な近似式を使っており、1980〜2099 年で有効。
/// 将来、法改正や特別な休日が追加された場合はこのファイルを更新すること。
library;

/// このクラスで計算できる年の範囲。
const holidayFirstYear = 1980;
const holidayLastYear = 2099;

final _cache = <int, Map<DateTime, String>>{};

/// [date] が祝日・休日ならその名前、そうでなければ null。
String? holidayName(DateTime date) =>
    holidaysOf(date.year)[DateTime(date.year, date.month, date.day)];

/// [year] 年の祝日・休日の一覧（日付 → 名前）。対象外の年は空。
Map<DateTime, String> holidaysOf(int year) {
  if (year < holidayFirstYear || year > holidayLastYear) return const {};
  return _cache.putIfAbsent(year, () => _compute(year));
}

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

/// 夏時間のある地域でもずれないよう、Duration ではなく日付で足す。
DateTime _plusDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// [year] 年 [month] 月の第 [n] 月曜日。
DateTime _nthMonday(int year, int month, int n) {
  final first = DateTime(year, month, 1);
  final offset = (DateTime.monday - first.weekday + 7) % 7;
  return DateTime(year, month, 1 + offset + 7 * (n - 1));
}

int _springEquinoxDay(int y) =>
    (20.8431 + 0.242194 * (y - 1980) - ((y - 1980) ~/ 4)).floor();

int _autumnEquinoxDay(int y) =>
    (23.2488 + 0.242194 * (y - 1980) - ((y - 1980) ~/ 4)).floor();

Map<DateTime, String> _compute(int y) {
  final h = <DateTime, String>{};

  // ---- 国民の祝日 ----
  h[_d(y, 1, 1)] = '元日';
  h[y >= 2000 ? _nthMonday(y, 1, 2) : _d(y, 1, 15)] = '成人の日';
  h[_d(y, 2, 11)] = '建国記念の日';
  if (y >= 2020) h[_d(y, 2, 23)] = '天皇誕生日';
  h[_d(y, 3, _springEquinoxDay(y))] = '春分の日';
  h[_d(y, 4, 29)] = y >= 2007
      ? '昭和の日'
      : y >= 1989
      ? 'みどりの日'
      : '天皇誕生日';
  h[_d(y, 5, 3)] = '憲法記念日';
  if (y >= 2007) h[_d(y, 5, 4)] = 'みどりの日';
  h[_d(y, 5, 5)] = 'こどもの日';

  // 海の日（2020・2021 年は東京オリンピック・パラリンピックのため移動）
  if (y == 2020) {
    h[_d(y, 7, 23)] = '海の日';
  } else if (y == 2021) {
    h[_d(y, 7, 22)] = '海の日';
  } else if (y >= 2003) {
    h[_nthMonday(y, 7, 3)] = '海の日';
  } else if (y >= 1996) {
    h[_d(y, 7, 20)] = '海の日';
  }

  // 山の日（2020・2021 年は移動）
  if (y == 2020) {
    h[_d(y, 8, 10)] = '山の日';
  } else if (y == 2021) {
    h[_d(y, 8, 8)] = '山の日';
  } else if (y >= 2016) {
    h[_d(y, 8, 11)] = '山の日';
  }

  h[y >= 2003 ? _nthMonday(y, 9, 3) : _d(y, 9, 15)] = '敬老の日';
  h[_d(y, 9, _autumnEquinoxDay(y))] = '秋分の日';

  // 体育の日 → スポーツの日（2020 年に改称。2020・2021 年は移動）
  if (y == 2020) {
    h[_d(y, 7, 24)] = 'スポーツの日';
  } else if (y == 2021) {
    h[_d(y, 7, 23)] = 'スポーツの日';
  } else if (y >= 2022) {
    h[_nthMonday(y, 10, 2)] = 'スポーツの日';
  } else if (y >= 2000) {
    h[_nthMonday(y, 10, 2)] = '体育の日';
  } else {
    h[_d(y, 10, 10)] = '体育の日';
  }

  h[_d(y, 11, 3)] = '文化の日';
  h[_d(y, 11, 23)] = '勤労感謝の日';
  // 平成の天皇誕生日（1989〜2018 年）。2019 年は天皇誕生日がない。
  if (y >= 1989 && y <= 2018) h[_d(y, 12, 23)] = '天皇誕生日';

  // ---- 特別に休日とされた日 ----
  const special = {
    (1989, 2, 24): '昭和天皇の大喪の礼',
    (1990, 11, 12): '即位礼正殿の儀',
    (1993, 6, 9): '皇太子徳仁親王の結婚の儀',
    (2019, 5, 1): '天皇の即位の日',
    (2019, 10, 22): '即位礼正殿の儀',
  };
  special.forEach((k, name) {
    if (k.$1 == y) h[_d(k.$1, k.$2, k.$3)] = name;
  });

  final holidays = Map.of(h);

  // ---- 振替休日 ----
  // 祝日が日曜日なら、その後のいちばん近い「祝日でない日」が休日になる。
  // （2006 年までは「翌日の月曜日」のみ）
  for (final date in h.keys.toList()..sort()) {
    if (date.weekday != DateTime.sunday) continue;
    var next = _plusDays(date, 1);
    if (y >= 2007) {
      while (holidays.containsKey(next)) {
        next = _plusDays(next, 1);
      }
    } else if (holidays.containsKey(next)) {
      continue;
    }
    if (next.year == y) holidays[next] = '振替休日';
  }

  // ---- 国民の休日 ----
  // 前日と翌日が国民の祝日である日（日曜日と、すでに休日の日を除く）。
  if (y >= 1988) {
    for (final date in h.keys.toList()..sort()) {
      final between = _plusDays(date, 1);
      final after = _plusDays(date, 2);
      if (h.containsKey(after) &&
          !holidays.containsKey(between) &&
          between.weekday != DateTime.sunday) {
        holidays[between] = '国民の休日';
      }
    }
  }

  return Map.unmodifiable(holidays);
}
