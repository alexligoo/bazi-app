import 'dart:io';

// ============ 基础数据 ============
const List<String> tianGan = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const List<String> diZhi = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
const List<int> ganWuXing = [0,0,1,1,2,2,3,3,4,4]; // 木火土金水
const List<String> wuXingName = ['木','火','土','金','水'];

const Map<String, List<String>> diZhiCangGan = {
  '子':['癸'],'丑':['己','癸','辛'],'寅':['甲','丙','戊'],'卯':['乙'],
  '辰':['戊','乙','癸'],'巳':['丙','庚','戊'],'午':['丁','己'],'未':['己','丁','乙'],
  '申':['庚','壬','戊'],'酉':['辛'],'戌':['戊','辛','丁'],'亥':['壬','甲'],
};

const List<String> shiChenName = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

// ============ 十神 ============
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

List<String> getZhiShiShenList(int dayGanIdx, String zhi) {
  final cg = diZhiCangGan[zhi] ?? [];
  return cg.map((g) => getShiShen(dayGanIdx, tianGan.indexOf(g))).toList();
}

// ============ 节气 ============
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

// ============ 四柱计算 ============
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

// ============ 大运 ============
Map<String, dynamic> getDaYun(DateTime birthDt, bool isMale, int yearGanIdx, int monthGanIdx, int monthZhiIdx) {
  bool isYangYear = yearGanIdx % 2 == 0;
  bool isForward = (isMale && isYangYear) || (!isMale && !isYangYear);

  DateTime lichun = getLiChun(birthDt.year);
  int nianYear = birthDt.isBefore(lichun) ? birthDt.year - 1 : birthDt.year;

  int currentMonthIdx = 1;
  for (int m = 1; m <= 12; m++) {
    DateTime jie = (m <= 11) ? getSolarTerm(nianYear, m * 2) : getSolarTerm(nianYear + 1, 0);
    if (birthDt.isBefore(jie)) { currentMonthIdx = m == 1 ? 12 : m - 1; break; }
    if (m == 12) currentMonthIdx = 12;
  }

  DateTime prevJie, nextJie;
  if (currentMonthIdx >= 12) {
    prevJie = getSolarTerm(nianYear + 1, 0);
    nextJie = getSolarTerm(nianYear + 1, 2);
  } else {
    prevJie = getSolarTerm(nianYear, currentMonthIdx * 2);
    nextJie = (currentMonthIdx + 1 <= 11) ? getSolarTerm(nianYear, (currentMonthIdx + 1) * 2) : getSolarTerm(nianYear + 1, 0);
  }

  int daysDiff = isForward ? nextJie.difference(birthDt).inDays.abs() : birthDt.difference(prevJie).inDays.abs();
  int startAge = (daysDiff / 3).round();
  if (startAge < 1) startAge = 1;

  List<List<int>> daYunList = [];
  for (int i = 1; i <= 10; i++) {
    int g, z;
    if (isForward) { g = (monthGanIdx + i) % 10; z = (monthZhiIdx + i) % 12; }
    else { g = (monthGanIdx - i % 10 + 10) % 10; z = (monthZhiIdx - i % 12 + 12) % 12; }
    daYunList.add([g, z]);
  }
  return {'startAge': startAge, 'daYunList': daYunList};
}

// ============ 纳音 ============
String getNaYin(int ganIdx, int zhiIdx) {
  int idx = -1;
  for (int i = 0; i < 60; i++) {
    if (i % 10 == ganIdx && i % 12 == zhiIdx) { idx = i; break; }
  }
  if (idx < 0) return '';
  const ny = ['金','金','火','火','木','木','土','土','金','金','火','火','木','木','土','土','金','金','火','火',
    '木','木','土','土','金','金','火','火','木','木','土','土','金','金','火','火','木','木','土','土',
    '金','金','火','火','木','木','土','土','金','金','火','火','木','木','土','土','金','金','火','火'];
  return ny[idx];
}

String getNaYinFull(int ganIdx, int zhiIdx) {
  int idx = -1;
  for (int i = 0; i < 60; i++) {
    if (i % 10 == ganIdx && i % 12 == zhiIdx) { idx = i; break; }
  }
  if (idx < 0) return '';
  const nyFull = [
    '海中金','海中金','炉中火','炉中火','大林木','大林木','路旁土','路旁土','剑锋金','剑锋金',
    '山头火','山头火','涧下水','涧下水','城头土','城头土','白蜡金','白蜡金','杨柳木','杨柳木',
    '泉中水','泉中水','屋上土','屋上土','霹雳火','霹雳火','松柏木','松柏木','长流水','长流水',
    '砂石金','砂石金','山下火','山下火','平地木','平地木','壁上土','壁上土','金箔金','金箔金',
    '覆灯火','覆灯火','天河水','天河水','大驿土','大驿土','钗钏金','钗钏金','桑柘木','桑柘木',
    '大溪水','大溪水','沙中土','沙中土','天上火','天上火','石榴木','石榴木','大海水','大海水',
  ];
  return nyFull[idx];
}

// ============ 农历 ============
const List<int> _lunarInfo = [
  0x04bd8,0x04ae0,0x0a570,0x054d5,0x0d260,0x0d950,0x16554,0x056a0,0x09ad0,0x055d2,
  0x04ae0,0x0a5b6,0x0a4d0,0x0d250,0x1d255,0x0b540,0x0d6a0,0x0ada2,0x095b0,0x14977,
  0x04970,0x0a4b0,0x0b4b5,0x06a50,0x06d40,0x1ab54,0x02b60,0x09570,0x052f2,0x04970,
  0x06566,0x0d4a0,0x0ea50,0x06e95,0x05ad0,0x02b60,0x186e3,0x092e0,0x1c8d7,0x0c950,
  0x0d4a0,0x1d8a6,0x0b550,0x056a0,0x1a5b4,0x025d0,0x092d0,0x0d2b2,0x0a950,0x0b557,
  0x06ca0,0x0b550,0x15355,0x04da0,0x0a5b0,0x14573,0x052b0,0x0a9a8,0x0e950,0x06aa0,
  0x0aea6,0x0ab50,0x04b60,0x0aae4,0x0a570,0x05260,0x0f263,0x0d950,0x05b57,0x056a0,
  0x096d0,0x04dd5,0x04ad0,0x0a4d0,0x0d4d4,0x0d250,0x0d558,0x0b540,0x0b6a0,0x195a6,
  0x095b0,0x049b0,0x0a974,0x0a4b0,0x0b27a,0x06a50,0x06d40,0x0af46,0x0ab60,0x09570,
  0x04af5,0x04970,0x064b0,0x074a3,0x0ea50,0x06b58,0x05ac0,0x0ab60,0x096d5,0x092e0,
  0x0c960,0x0d954,0x0d4a0,0x0da50,0x07552,0x056a0,0x0abb7,0x025d0,0x092d0,0x0cab5,
  0x0a950,0x0b4a0,0x0baa4,0x0ad50,0x055d9,0x04ba0,0x0a5b0,0x15176,0x052b0,0x0a930,
  0x07954,0x06aa0,0x0ad50,0x05b52,0x04b60,0x0a6e6,0x0a4e0,0x0d260,0x0ea65,0x0d530,
  0x05aa0,0x076a3,0x096d0,0x04afb,0x04ad0,0x0a4d0,0x1d0b6,0x0d250,0x0d520,0x0dd45,
  0x0b5a0,0x056d0,0x055b2,0x049b0,0x0a577,0x0a4b0,0x0aa50,0x1b255,0x06d20,0x0ada0,
  0x14b63,0x09370,0x049f8,0x04970,0x064b0,0x168a6,0x0ea50,0x06b20,0x1a6c4,0x0aae0,
  0x092e0,0x0d2e3,0x0c960,0x0d557,0x0d4a0,0x0da50,0x05d55,0x056a0,0x0a6d0,0x055d4,
  0x052d0,0x0a9b8,0x0a950,0x0b4a0,0x0b6a6,0x0ad50,0x055a0,0x0aba4,0x0a5b0,0x052b0,
  0x0b273,0x06930,0x07337,0x06aa0,0x0ad50,0x14b55,0x04b60,0x0a570,0x054e4,0x0d160,
  0x0e968,0x0d520,0x0daa0,0x16aa6,0x056d0,0x04ae0,0x0a9d4,0x0a4d0,0x0d150,0x0f252,
  0x0d520,
];

int _lunarMonthDays(int year, int month) => (_lunarInfo[year - 1900] & (0x10000 >> month)) != 0 ? 30 : 29;
int _lunarLeapMonth(int year) => _lunarInfo[year - 1900] & 0xf;
int _lunarLeapDays(int year) {
  if (_lunarLeapMonth(year) == 0) return 0;
  return (_lunarInfo[year - 1900] & 0x10000) != 0 ? 30 : 29;
}
int _lunarYearDays(int year) {
  int sum = 348;
  for (int i = 0x8000; i > 0x8; i >>= 1) { sum += (_lunarInfo[year - 1900] & i) != 0 ? 1 : 0; }
  return sum + _lunarLeapDays(year);
}

List<int> solarToLunar(int sy, int sm, int sd) {
  DateTime baseDate = DateTime(1900, 1, 31);
  DateTime solarDate = DateTime(sy, sm, sd);
  int offset = solarDate.difference(baseDate).inDays;

  int lunarYear = 1900;
  for (; lunarYear < 2101; lunarYear++) {
    int yDays = _lunarYearDays(lunarYear);
    if (offset < yDays) break;
    offset -= yDays;
  }

  int leapMonth = _lunarLeapMonth(lunarYear);
  int lunarMonth = 1;
  bool isLeapMonth = false;

  for (int i = 1; i <= 12; i++) {
    int mDays = _lunarMonthDays(lunarYear, i);
    if (offset < mDays) { lunarMonth = i; break; }
    offset -= mDays;
    if (leapMonth == i) {
      int lDays = _lunarLeapDays(lunarYear);
      if (offset < lDays) { lunarMonth = i; isLeapMonth = true; break; }
      offset -= lDays;
    }
    if (i == 12) lunarMonth = 12;
  }

  int lunarDay = offset + 1;
  return [lunarYear, lunarMonth, lunarDay, isLeapMonth ? 1 : 0];
}

String lunarMonthName(int m) {
  const names = ['','正','二','三','四','五','六','七','八','九','十','冬','腊'];
  return (m >= 1 && m <= 12) ? names[m] : '$m';
}
String lunarDayName(int d) {
  const tens = ['初','十','廿','三'];
  const ones = ['','一','二','三','四','五','六','七','八','九','十'];
  if (d == 10) return '初十';
  if (d == 20) return '二十';
  if (d == 30) return '三十';
  return '${tens[d ~/ 10]}${ones[d % 10]}';
}

// ============ 主函数 ============
void main() {
  final samples = [
    {'dt': DateTime(1963, 2, 14, 6), 'male': true},
    {'dt': DateTime(1971, 8, 3, 15), 'male': false},
    {'dt': DateTime(1984, 11, 28, 23), 'male': true},
    {'dt': DateTime(1992, 6, 21, 10), 'male': false},
    {'dt': DateTime(1958, 9, 17, 4), 'male': true},
    {'dt': DateTime(2001, 3, 8, 13), 'male': false},
    {'dt': DateTime(1976, 12, 31, 0), 'male': true},
    {'dt': DateTime(1989, 1, 20, 19), 'male': false},
    {'dt': DateTime(2008, 5, 12, 14), 'male': true},
    {'dt': DateTime(1967, 4, 5, 7), 'male': false},
    {'dt': DateTime(1955, 10, 10, 22), 'male': true},
    {'dt': DateTime(1998, 7, 25, 3), 'male': false},
    {'dt': DateTime(2012, 12, 21, 11), 'male': true},
    {'dt': DateTime(1974, 3, 22, 16), 'male': false},
    {'dt': DateTime(1986, 9, 1, 5), 'male': true},
    {'dt': DateTime(2006, 1, 29, 8), 'male': false},
    {'dt': DateTime(1961, 7, 18, 20), 'male': true},
    {'dt': DateTime(1994, 11, 5, 1), 'male': false},
    {'dt': DateTime(2018, 8, 18, 12), 'male': true},
    {'dt': DateTime(1979, 5, 27, 9), 'male': false},
    {'dt': DateTime(1952, 1, 3, 2), 'male': true},
    {'dt': DateTime(2003, 4, 15, 17), 'male': false},
    {'dt': DateTime(1968, 10, 22, 21), 'male': true},
    {'dt': DateTime(1991, 2, 9, 6), 'male': false},
    {'dt': DateTime(2016, 6, 6, 14), 'male': true},
    {'dt': DateTime(1983, 8, 30, 0), 'male': false},
    {'dt': DateTime(1957, 3, 12, 11), 'male': true},
    {'dt': DateTime(2009, 9, 28, 18), 'male': false},
    {'dt': DateTime(1975, 12, 15, 23), 'male': true},
    {'dt': DateTime(2000, 2, 5, 7), 'male': false},
  ];

  StringBuffer sb = StringBuffer();
  sb.writeln('=' * 70);
  sb.writeln('八字排盘校验数据（共30例）');
  sb.writeln('生成时间：${DateTime.now()}');
  sb.writeln('=' * 70);

  for (int i = 0; i < samples.length; i++) {
    DateTime dt = samples[i]['dt'] as DateTime;
    bool isMale = samples[i]['male'] as bool;

    DateTime adjustedDt = dt;
    if (dt.hour == 23) adjustedDt = dt.add(Duration(days: 1));
    final yp = getYearPillar(dt);
    final mp = getMonthPillar(dt, yp[0]);
    final dp = getDayPillar(adjustedDt);
    final hp = getHourPillar(dt.hour, dp[0]);
    final daYun = getDaYun(dt, isMale, yp[0], mp[0], mp[1]);
    int startAge = daYun['startAge'];
    List<List<int>> daYunList = daYun['daYunList'];

    // 命宫
    int mingZhiIdx = (4 - mp[1] + hp[1] + 12) % 12;
    int baseGan = (yp[0] % 5) * 2 + 2;
    int ganSteps = (mingZhiIdx - 2 + 12) % 12;
    int mingGanIdx = (baseGan + ganSteps) % 10;

    // 农历
    final lunar = solarToLunar(dt.year, dt.month, dt.day);
    int zhiIdx = (dt.hour == 23 || dt.hour == 0) ? 0 : ((dt.hour + 1) ~/ 2) % 12;

    // 十神
    String yearSS = getShiShen(dp[0], yp[0]);
    String monthSS = getShiShen(dp[0], mp[0]);
    String hourSS = getShiShen(dp[0], hp[0]);

    // 藏干十神
    List<String> yearZhiSS = getZhiShiShenList(dp[0], diZhi[yp[1]]);
    List<String> monthZhiSS = getZhiShiShenList(dp[0], diZhi[mp[1]]);
    List<String> dayZhiSS = getZhiShiShenList(dp[0], diZhi[dp[1]]);
    List<String> hourZhiSS = getZhiShiShenList(dp[0], diZhi[hp[1]]);

    // 纳音
    String nyYear = getNaYinFull(yp[0], yp[1]);
    String nyMonth = getNaYinFull(mp[0], mp[1]);
    String nyDay = getNaYinFull(dp[0], dp[1]);
    String nyHour = getNaYinFull(hp[0], hp[1]);
    String nyMing = getNaYinFull(mingGanIdx, mingZhiIdx);

    sb.writeln('');
    sb.writeln('【第${i + 1}例】');
    sb.writeln('公历：${dt.year}年${dt.month}月${dt.day}日 ${dt.hour}时');
    sb.writeln('农历：${lunar[0]}年${lunarMonthName(lunar[1])}月${lunarDayName(lunar[2])}');
    sb.writeln('性别：${isMale ? "男（乾造）" : "女（坤造）"}');
    sb.writeln('时辰：${shiChenName[zhiIdx]}时');
    sb.writeln('');
    sb.writeln('四柱：');
    sb.writeln('        时柱      日柱      月柱      年柱');
    sb.writeln('天干：  ${tianGan[hp[0]]}        ${tianGan[dp[0]]}        ${tianGan[mp[0]]}        ${tianGan[yp[0]]}');
    sb.writeln('地支：  ${diZhi[hp[1]]}        ${diZhi[dp[1]]}        ${diZhi[mp[1]]}        ${diZhi[yp[1]]}');
    sb.writeln('');
    sb.writeln('天干十神：');
    sb.writeln('  时干：$hourSS  日干：日主  月干：$monthSS  年干：$yearSS');
    sb.writeln('');
    sb.writeln('地支藏干十神：');
    sb.writeln('  时支${diZhi[hp[1]]}藏：${_formatCangGan(diZhi[hp[1]], hourZhiSS)}');
    sb.writeln('  日支${diZhi[dp[1]]}藏：${_formatCangGan(diZhi[dp[1]], dayZhiSS)}');
    sb.writeln('  月支${diZhi[mp[1]]}藏：${_formatCangGan(diZhi[mp[1]], monthZhiSS)}');
    sb.writeln('  年支${diZhi[yp[1]]}藏：${_formatCangGan(diZhi[yp[1]], yearZhiSS)}');
    sb.writeln('');
    sb.writeln('纳音：');
    sb.writeln('  年柱：${tianGan[yp[0]]}${diZhi[yp[1]]} $nyYear');
    sb.writeln('  月柱：${tianGan[mp[0]]}${diZhi[mp[1]]} $nyMonth');
    sb.writeln('  日柱：${tianGan[dp[0]]}${diZhi[dp[1]]} $nyDay');
    sb.writeln('  时柱：${tianGan[hp[0]]}${diZhi[hp[1]]} $nyHour');
    sb.writeln('');
    sb.writeln('命宫：${tianGan[mingGanIdx]}${diZhi[mingZhiIdx]}（纳音：$nyMing）');
    sb.writeln('');
    sb.writeln('大运（起运${startAge}岁）：');
    StringBuffer dyLine = StringBuffer();
    for (int j = 0; j < daYunList.length; j++) {
      int age = startAge + j * 10;
      String gz = '${tianGan[daYunList[j][0]]}${diZhi[daYunList[j][1]]}';
      dyLine.write('  $age岁$gz');
    }
    sb.writeln(dyLine.toString());
    sb.writeln('-' * 70);
  }

  File('/Users/alexli/bazi_app/bazi_30samples.txt').writeAsStringSync(sb.toString());
  print('已生成 bazi_30samples.txt');
}

String _formatCangGan(String zhi, List<String> ssList) {
  final cg = diZhiCangGan[zhi] ?? [];
  StringBuffer s = StringBuffer();
  for (int i = 0; i < cg.length; i++) {
    if (i > 0) s.write('、');
    s.write('${cg[i]}(${ssList[i]})');
  }
  return s.toString();
}
