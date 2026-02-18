// Full verification of Example 3: 1978-01-05 23:00, Male
const List<String> tianGan = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const List<String> diZhi = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
const List<int> ganWuXing = [0,0,1,1,2,2,3,3,4,4];

const Map<String, List<String>> diZhiCangGan = {
  '子':['癸'],'丑':['己','癸','辛'],'寅':['甲','丙','戊'],'卯':['乙'],
  '辰':['戊','乙','癸'],'巳':['丙','庚','戊'],'午':['丁','己'],'未':['己','丁','乙'],
  '申':['庚','壬','戊'],'酉':['辛'],'戌':['戊','辛','丁'],'亥':['壬','甲'],
};

String getShiShen(int dayGanIdx, int otherGanIdx) {
  int meWx = ganWuXing[dayGanIdx];
  int otherWx = ganWuXing[otherGanIdx];
  bool sameYY = (dayGanIdx % 2) == (otherGanIdx % 2);
  if (meWx == otherWx) return sameYY ? '比肩' : '劫财';
  if ((meWx + 1) % 5 == otherWx) return sameYY ? '食神' : '伤官';
  if ((meWx + 2) % 5 == otherWx) return sameYY ? '偏财' : '正财';
  if ((meWx + 3) % 5 == otherWx) return sameYY ? '七杀' : '正官';
  if ((meWx + 4) % 5 == otherWx) return sameYY ? '偏印' : '正印';
  return '';
}

DateTime getSolarTerm(int year, int n) {
  const double baseJd = 2451550.5;
  final double y = (year - 2000).toDouble();
  final double jd = baseJd + 365.2422 * y + n * 15.218425;
  return _jdToDateTime(jd + 8.0 / 24.0);
}
DateTime _jdToDateTime(double jd) {
  final int z = (jd + 0.5).floor();
  final double f = jd + 0.5 - z;
  int a;
  if (z < 2299161) { a = z; } else {
    final int alpha = ((z - 1867216.25) / 36524.25).floor();
    a = z + 1 + alpha - (alpha ~/ 4);
  }
  final int b = a + 1524;
  final int c = ((b - 122.1) / 365.25).floor();
  final int d = (365.25 * c).floor();
  final int e = ((b - d) / 30.6001).floor();
  final int day = b - d - (30.6001 * e).floor();
  final int month = (e < 14) ? e - 1 : e - 13;
  final int year = (month > 2) ? c - 4716 : c - 4715;
  final double hourFrac = f * 24.0;
  return DateTime(year, month, day, hourFrac.floor(), ((hourFrac - hourFrac.floor()) * 60).floor());
}
DateTime getLiChun(int year) => getSolarTerm(year, 2);

List<int> getYearPillar(DateTime dt) {
  final DateTime lichun = getLiChun(dt.year);
  int year = dt.isBefore(lichun) ? dt.year - 1 : dt.year;
  return [(year - 4) % 10, (year - 4) % 12];
}
List<int> getMonthPillar(DateTime dt, int yearGanIdx) {
  final DateTime lichun = getLiChun(dt.year);
  int nianYear = dt.isBefore(lichun) ? dt.year - 1 : dt.year;
  int monthIdx = 1;
  for (int m = 1; m <= 12; m++) {
    DateTime jie = (m <= 11) ? getSolarTerm(nianYear, m * 2) : getSolarTerm(nianYear + 1, 0);
    if (dt.isBefore(jie)) { monthIdx = m == 1 ? 12 : m - 1; break; }
    if (m == 12) monthIdx = 12;
  }
  int zhiIdx = (monthIdx + 1) % 12;
  int startGan = (yearGanIdx % 5) * 2 + 2;
  int ganIdx = (startGan + monthIdx - 1) % 10;
  return [ganIdx, zhiIdx];
}
List<int> getDayPillar(DateTime dt) {
  int y = dt.year, m = dt.month, d = dt.day;
  if (m <= 2) { y -= 1; m += 12; }
  int a2 = y ~/ 100;
  int b2 = 2 - a2 + a2 ~/ 4;
  int jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b2 - 1524;
  int idx = (jd - 11) % 60;
  if (idx < 0) idx += 60;
  return [idx % 10, idx % 12];
}
List<int> getHourPillar(int hour, int dayGanIdx) {
  int zhiIdx;
  if (hour == 23 || hour == 0) { zhiIdx = 0; } else { zhiIdx = ((hour + 1) ~/ 2) % 12; }
  int startGan = (dayGanIdx % 5) * 2;
  return [(startGan + zhiIdx) % 10, zhiIdx];
}

void main() {
  DateTime dt = DateTime(1978, 1, 5, 23);
  bool isMale = true;

  print('=== 第3例完整排盘验证 ===');
  print('公历: 1978-01-05 23:00, 男\n');

  // Step 1: Year/Month use original dt (not adjusted)
  final yp = getYearPillar(dt);
  final mp = getMonthPillar(dt, yp[0]);
  print('年柱: ${tianGan[yp[0]]}${diZhi[yp[1]]} (年干idx=${yp[0]}, 年支idx=${yp[1]})');
  print('月柱: ${tianGan[mp[0]]}${diZhi[mp[1]]} (月干idx=${mp[0]}, 月支idx=${mp[1]})');

  // Step 2: Day pillar - 23点换日
  DateTime adjustedDt = dt.add(Duration(days: 1)); // → 1978-01-06
  final dp = getDayPillar(adjustedDt);
  print('日柱: ${tianGan[dp[0]]}${diZhi[dp[1]]} (基于${adjustedDt.year}-${adjustedDt.month.toString().padLeft(2,"0")}-${adjustedDt.day.toString().padLeft(2,"0")})');

  // Step 3: Hour pillar - 基于换日后的日干
  final hp = getHourPillar(dt.hour, dp[0]);
  print('时柱: ${tianGan[hp[0]]}${diZhi[hp[1]]} (23点=子时, 基于日干${tianGan[dp[0]]})');

  // Verify 五鼠遁时
  print('\n五鼠遁时验证:');
  print('日干: ${tianGan[dp[0]]}(idx=${dp[0]})');
  print('日干 % 5 = ${dp[0] % 5}');
  print('startGan = ${dp[0] % 5} * 2 = ${(dp[0] % 5) * 2}');
  print('子时干 = startGan + 0 = ${(dp[0] % 5) * 2} → ${tianGan[(dp[0] % 5) * 2]}');

  // 五鼠遁时口诀:
  // 甲己之日起甲子 (甲=0,己=5 → %5=0 → startGan=0 → 甲)
  // 乙庚之日起丙子 (乙=1,庚=6 → %5=1 → startGan=2 → 丙)
  // 丙辛之日起戊子 (丙=2,辛=7 → %5=2 → startGan=4 → 戊)
  // 丁壬之日起庚子 (丁=3,壬=8 → %5=3 → startGan=6 → 庚)
  // 戊癸之日起壬子 (戊=4,癸=9 → %5=4 → startGan=8 → 壬)
  print('\n口诀验证:');
  print('戊日(idx=4) → %5=4 → 戊癸之日起壬子 → 子时天干=壬 ✓');

  print('\n完整四柱:');
  print('年: ${tianGan[yp[0]]}${diZhi[yp[1]]}');
  print('月: ${tianGan[mp[0]]}${diZhi[mp[1]]}');
  print('日: ${tianGan[dp[0]]}${diZhi[dp[1]]}');
  print('时: ${tianGan[hp[0]]}${diZhi[hp[1]]}');

  // Also verify: what if we DON'T adjust for 23:00?
  print('\n--- 对比: 如果不换日 ---');
  final dpNoAdj = getDayPillar(DateTime(1978, 1, 5));
  final hpNoAdj = getHourPillar(23, dpNoAdj[0]);
  print('日柱(不换日): ${tianGan[dpNoAdj[0]]}${diZhi[dpNoAdj[1]]}');
  print('时柱(不换日): ${tianGan[hpNoAdj[0]]}${diZhi[hpNoAdj[1]]}');
  print('丁日(idx=3) → %5=3 → 丁壬之日起庚子 → 子时天干=庚');

  print('\n=== 结论 ===');
  print('当前代码: 23点→日柱进入次日(戊辰)→时干基于戊日推壬子 → 自洽 ✓');
  print('如果不换日: 日柱丁卯→时干基于丁日推庚子 → 也自洽');
  print('两种都是合法的八字流派选择，关键是日柱和时干必须配套');
}
