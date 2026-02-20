import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';

// ============================================================
// 八字排盘 App — 传统大师纸风格（全面重构版）
// ============================================================

const bool debugMode = false;
const bool isAccurateSolarTerm = false;

const Color kBgColor = Color(0xFFF8F0E5); // 宣纸色
const Color kTextColor = Color(0xFF5C4033); // 深褐色

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('bazi_records');
  runApp(const BaZiApp());
}

class BaZiApp extends StatelessWidget {
  const BaZiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '八字排盘',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBgColor,
        fontFamilyFallback: const ['PingFang SC', 'Heiti SC', 'Microsoft YaHei', 'SimHei', 'sans-serif'],
      ),
      home: const InputPage(),
    );
  }
}

// ============================================================
// 基础数据
// ============================================================
const List<String> tianGan = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const List<String> diZhi = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
const List<int> ganWuXing = [0,0,1,1,2,2,3,3,4,4]; // 木火土金水

const Map<String, List<String>> diZhiCangGan = {
  '子':['癸'],'丑':['己','癸','辛'],'寅':['甲','丙','戊'],'卯':['乙'],
  '辰':['戊','乙','癸'],'巳':['丙','庚','戊'],'午':['丁','己'],'未':['己','丁','乙'],
  '申':['庚','壬','戊'],'酉':['辛'],'戌':['戊','辛','丁'],'亥':['壬','甲'],
};

const List<String> hanNum = ['零','一','二','三','四','五','六','七','八','九','十',
  '十一','十二','十三','十四','十五','十六','十七','十八','十九','二十',
  '二十一','二十二','二十三','二十四','二十五','二十六','二十七','二十八','二十九','三十',
  '三十一','三十二','三十三','三十四','三十五','三十六','三十七','三十八','三十九','四十',
  '四十一','四十二','四十三','四十四','四十五','四十六','四十七','四十八','四十九','五十',
  '五十一','五十二','五十三','五十四','五十五','五十六','五十七','五十八','五十九','六十',
  '六十一','六十二','六十三','六十四','六十五','六十六','六十七','六十八','六十九','七十',
  '七十一','七十二','七十三','七十四','七十五','七十六','七十七','七十八','七十九','八十',
  '八十一','八十二','八十三','八十四','八十五','八十六','八十七','八十八','八十九','九十',
  '九十一','九十二','九十三','九十四','九十五','九十六','九十七','九十八','九十九','一百'];

// 地支对应时辰名
const List<String> shiChenName = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

// ============================================================
// 十神
// ============================================================
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

/// 十神简称（大运用）
String getShiShenShort(int dayGanIdx, int otherGanIdx) {
  const map = {'比肩':'比','劫财':'劫','食神':'食','伤官':'伤',
    '偏财':'财','正财':'才','七杀':'杀','正官':'官','偏印':'枭','正印':'印'};
  return map[getShiShen(dayGanIdx, otherGanIdx)] ?? '';
}

/// 地支藏干十神（连写）
String getZhiShiShen(int dayGanIdx, String zhi) {
  final cg = diZhiCangGan[zhi] ?? [];
  return cg.map((g) => getShiShen(dayGanIdx, tianGan.indexOf(g))).join('');
}

/// 地支藏干十神（列表，每个词组独立）
List<String> getZhiShiShenList(int dayGanIdx, String zhi) {
  final cg = diZhiCangGan[zhi] ?? [];
  return cg.map((g) => getShiShen(dayGanIdx, tianGan.indexOf(g))).toList();
}

// ============================================================
// 节气近似算法
// ============================================================
DateTime getSolarTerm(int year, int n) {
  const double baseJd = 2451550.5; // J2000.0 Xiao Han (Jan 6, 2000)
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

// ============================================================
// 大运
// ============================================================
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

// ============================================================
// 农历转换（简化版 — 1900~2100 查表）
// ============================================================
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

/// 农历月份天数
int _lunarMonthDays(int year, int month) {
  return (_lunarInfo[year - 1900] & (0x10000 >> month)) != 0 ? 30 : 29;
}

/// 农历闰月（0=无闰月）
int _lunarLeapMonth(int year) => _lunarInfo[year - 1900] & 0xf;

/// 农历闰月天数
int _lunarLeapDays(int year) {
  if (_lunarLeapMonth(year) == 0) return 0;
  return (_lunarInfo[year - 1900] & 0x10000) != 0 ? 30 : 29;
}

/// 农历一年总天数
int _lunarYearDays(int year) {
  int sum = 348;
  for (int i = 0x8000; i > 0x8; i >>= 1) {
    sum += (_lunarInfo[year - 1900] & i) != 0 ? 1 : 0;
  }
  return sum + _lunarLeapDays(year);
}

/// 公历转农历，返回 [年, 月, 日, 是否闰月]
List<int> solarToLunar(int sy, int sm, int sd) {
  DateTime baseDate = DateTime(1900, 1, 31); // 农历1900年正月初一
  DateTime solarDate = DateTime(sy, sm, sd);
  int offset = solarDate.difference(baseDate).inDays;

  // 修正点1&2：修正年/月查找逻辑，解决闰月处理导致的农历日期偏差
  // 查找农历年
  int lunarYear = 1900;
  for (; lunarYear < 2101; lunarYear++) {
    int yDays = _lunarYearDays(lunarYear);
    if (offset < yDays) break;
    offset -= yDays;
  }

  // 查找农历月（正确处理闰月）
  int leapMonth = _lunarLeapMonth(lunarYear);
  int lunarMonth = 1;
  bool isLeapMonth = false;

  for (int i = 1; i <= 12; i++) {
    int mDays = _lunarMonthDays(lunarYear, i);
    if (offset < mDays) {
      lunarMonth = i;
      break;
    }
    offset -= mDays;

    // 闰月紧跟在对应月份之后
    if (leapMonth == i) {
      int lDays = _lunarLeapDays(lunarYear);
      if (offset < lDays) {
        lunarMonth = i;
        isLeapMonth = true;
        break;
      }
      offset -= lDays;
    }

    if (i == 12) lunarMonth = 12;
  }

  int lunarDay = offset + 1;
  return [lunarYear, lunarMonth, lunarDay, isLeapMonth ? 1 : 0];
}

/// 农历月份名
String lunarMonthName(int m) {
  const names = ['','正','二','三','四','五','六','七','八','九','十','冬','腊'];
  return (m >= 1 && m <= 12) ? names[m] : '$m';
}

/// 农历日期名
String lunarDayName(int d) {
  const tens = ['初','十','廿','三'];
  const ones = ['','一','二','三','四','五','六','七','八','九','十'];
  if (d == 10) return '初十';
  if (d == 20) return '二十';
  if (d == 30) return '三十';
  return '${tens[d ~/ 10]}${ones[d % 10]}';
}

// ============================================================
// 纳音五行
// ============================================================
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

// ============================================================
// 数据模型
// ============================================================
class BaZiResult {
  final int yearGan, yearZhi, monthGan, monthZhi, dayGan, dayZhi, hourGan, hourZhi;
  final int startAge;
  final List<List<int>> daYunList;
  final bool isMale;
  final DateTime birthDt;
  final String name;

  BaZiResult({
    required this.yearGan, required this.yearZhi,
    required this.monthGan, required this.monthZhi,
    required this.dayGan, required this.dayZhi,
    required this.hourGan, required this.hourZhi,
    required this.startAge, required this.daYunList,
    required this.isMale, required this.birthDt,
    this.name = '',
  });

  String get yearGanStr => tianGan[yearGan];
  String get yearZhiStr => diZhi[yearZhi];
  String get monthGanStr => tianGan[monthGan];
  String get monthZhiStr => diZhi[monthZhi];
  String get dayGanStr => tianGan[dayGan];
  String get dayZhiStr => diZhi[dayZhi];
  String get hourGanStr => tianGan[hourGan];
  String get hourZhiStr => diZhi[hourZhi];
}

BaZiResult calculate(DateTime dt, bool isMale, {String name = ''}) {
  DateTime adjustedDt = dt;
  if (dt.hour == 23) adjustedDt = dt.add(const Duration(days: 1));
  final yp = getYearPillar(dt);
  final mp = getMonthPillar(dt, yp[0]);
  final dp = getDayPillar(adjustedDt);
  final hp = getHourPillar(dt.hour, dp[0]);
  final daYun = getDaYun(dt, isMale, yp[0], mp[0], mp[1]);
  return BaZiResult(
    yearGan: yp[0], yearZhi: yp[1], monthGan: mp[0], monthZhi: mp[1],
    dayGan: dp[0], dayZhi: dp[1], hourGan: hp[0], hourZhi: hp[1],
    startAge: daYun['startAge'], daYunList: daYun['daYunList'],
    isMale: isMale, birthDt: dt, name: name,
  );
}

// ============================================================
// 智能文本解析 — 万能八字信息识别
// ============================================================
const Map<String, int> _shiChenMap = {
  '子': 0, '丑': 2, '寅': 4, '卯': 6, '辰': 8, '巳': 10,
  '午': 12, '未': 14, '申': 16, '酉': 18, '戌': 20, '亥': 22,
};

int _adjustHourByPeriod(int h, String period) {
  switch (period) {
    case '凌晨': return h; // 0~5
    case '早上': case '上午': return h < 12 ? h : h;
    case '中午': return h == 12 ? 12 : h + 12;
    case '下午': return h < 12 ? h + 12 : h;
    case '傍晚': return h < 12 ? h + 12 : h;
    case '晚上': return h < 12 ? h + 12 : h;
    default: return h;
  }
}

int _parseLunarDay(String s) {
  const dayMap = {
    '初一':1,'初二':2,'初三':3,'初四':4,'初五':5,'初六':6,'初七':7,'初八':8,'初九':9,'初十':10,
    '十一':11,'十二':12,'十三':13,'十四':14,'十五':15,'十六':16,'十七':17,'十八':18,'十九':19,
    '二十':20,'廿一':21,'廿二':22,'廿三':23,'廿四':24,'廿五':25,'廿六':26,'廿七':27,'廿八':28,'廿九':29,
    '二十一':21,'二十二':22,'二十三':23,'二十四':24,'二十五':25,'二十六':26,'二十七':27,'二十八':28,'二十九':29,
    '三十':30,
  };
  return dayMap[s] ?? 1;
}

int _parseLunarMonth(String s) {
  if (s == '正月') return 1;
  if (s == '腊月') return 12;
  if (s == '冬月') return 11;
  const mMap = {'一':1,'二':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9,'十':10,'十一':11,'十二':12};
  final cleaned = s.replaceAll('月', '');
  return mMap[cleaned] ?? 1;
}

/// 农历转公历
DateTime? lunarToSolar(int lunarYear, int lunarMonth, int lunarDay) {
  for (int sy = lunarYear - 1; sy <= lunarYear + 1; sy++) {
    for (int sm = 1; sm <= 12; sm++) {
      int dim = DateTime(sy, sm + 1, 0).day;
      for (int sd = 1; sd <= dim; sd++) {
        final l = solarToLunar(sy, sm, sd);
        if (l[0] == lunarYear && l[1] == lunarMonth && l[2] == lunarDay) {
          return DateTime(sy, sm, sd);
        }
      }
    }
  }
  return null;
}

Map<String, dynamic> parseInput(String text) {
  text = text.trim();
  int? year, month, day, hour;
  bool? isMale;
  String name = '';
  bool isLunar = false;
  String work = text;

  // ===== 性别 =====
  if (RegExp(r'先生').hasMatch(work)) isMale = true;
  if (RegExp(r'女士').hasMatch(work)) isMale = false;
  if (work.contains('男命')) isMale = true;
  if (work.contains('女命')) isMale = false;
  if (work.contains('性别男')) isMale = true;
  if (work.contains('性别女')) isMale = false;
  if (isMale == null && RegExp(r'女').hasMatch(work)) isMale = false;
  if (isMale == null && RegExp(r'男').hasMatch(work)) isMale = true;

  // ===== 日期 =====
  // 1) yyyy年M月d日
  var dm = RegExp(r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]?').firstMatch(work);
  if (dm != null) {
    year = int.parse(dm.group(1)!); month = int.parse(dm.group(2)!); day = int.parse(dm.group(3)!);
    work = work.replaceFirst(dm.group(0)!, ' ');
  }
  // 2) yyyy-M-d / yyyy/M/d
  if (year == null) {
    dm = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(work);
    if (dm != null) {
      year = int.parse(dm.group(1)!); month = int.parse(dm.group(2)!); day = int.parse(dm.group(3)!);
      work = work.replaceFirst(dm.group(0)!, ' ');
    }
  }
  // 3) 12位连续数字 yyyyMMddHHmm
  if (year == null) {
    dm = RegExp(r'(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})').firstMatch(work);
    if (dm != null) {
      year = int.parse(dm.group(1)!); month = int.parse(dm.group(2)!); day = int.parse(dm.group(3)!);
      hour = int.parse(dm.group(4)!);
      work = work.replaceFirst(dm.group(0)!, ' ');
    }
  }
  // 4) 8位连续数字 yyyyMMdd
  if (year == null) {
    dm = RegExp(r'(\d{4})(\d{2})(\d{2})').firstMatch(work);
    if (dm != null) {
      year = int.parse(dm.group(1)!); month = int.parse(dm.group(2)!); day = int.parse(dm.group(3)!);
      work = work.replaceFirst(dm.group(0)!, ' ');
    }
  }

  // ===== 农历检测 =====
  bool hasLunarKeyword = work.contains('农历') || work.contains('正月') || work.contains('腊月');
  // yyyy年+农历月名+农历日名
  if (year == null) {
    dm = RegExp(r'(\d{4})\s*年\s*(?:农历\s*)?(正月|腊月|冬月|[一二三四五六七八九十]+月)').firstMatch(work);
    if (dm != null) {
      year = int.parse(dm.group(1)!);
      month = _parseLunarMonth(dm.group(2)!);
      isLunar = true;
      hasLunarKeyword = true;
      work = work.replaceFirst(dm.group(0)!, ' ');
    }
  }
  // 已有year但含农历关键词，覆盖月份
  if (year != null && hasLunarKeyword && !isLunar) {
    isLunar = true;
    var lmm = RegExp(r'(正月|腊月|冬月)').firstMatch(work);
    if (lmm != null) {
      month = _parseLunarMonth(lmm.group(1)!);
    }
  }
  // 农历日
  if (isLunar) {
    var ldm = RegExp(r'(初[一二三四五六七八九十]|十[一二三四五六七八九]|二十[一二三四五六七八九]?|廿[一二三四五六七八九]|三十)').firstMatch(work);
    if (ldm != null) {
      day = _parseLunarDay(ldm.group(0)!);
      work = work.replaceFirst(ldm.group(0)!, ' ');
    }
  }

  // ===== 时间 =====
  // 时辰
  var tm = RegExp(r'([子丑寅卯辰巳午未申酉戌亥])时').firstMatch(work);
  if (tm != null && hour == null) {
    hour = _shiChenMap[tm.group(1)!];
    work = work.replaceFirst(tm.group(0)!, ' ');
  }
  // HH:MM
  if (hour == null) {
    tm = RegExp(r'(\d{1,2}):(\d{1,2})').firstMatch(work);
    if (tm != null) {
      hour = int.parse(tm.group(1)!);
      work = work.replaceFirst(tm.group(0)!, ' ');
    }
  }
  // 模糊时段 + 数字点/时
  if (hour == null) {
    tm = RegExp(r'(凌晨|早上|上午|中午|下午|傍晚|晚上)\s*(\d{1,2})\s*[点时](?:\s*(\d{1,2})\s*分)?').firstMatch(work);
    if (tm != null) {
      hour = _adjustHourByPeriod(int.parse(tm.group(2)!), tm.group(1)!);
      work = work.replaceFirst(tm.group(0)!, ' ');
    }
  }
  // 纯数字 H点M分 / H时M分
  if (hour == null) {
    tm = RegExp(r'(\d{1,2})\s*[点时]\s*(?:(\d{1,2})\s*分)?').firstMatch(work);
    if (tm != null) {
      hour = int.parse(tm.group(1)!);
      work = work.replaceFirst(tm.group(0)!, ' ');
    }
  }
  // 仅模糊时段（无数字）
  if (hour == null) {
    const fuzzy = {'凌晨':2,'早上':7,'上午':9,'中午':12,'下午':15,'傍晚':18,'晚上':21};
    for (var e in fuzzy.entries) {
      if (work.contains(e.key)) { hour = e.value; break; }
    }
  }

  // ===== 姓名 =====
  // 1) XXX先生 / XXX女士
  var nm = RegExp(r'([\u4e00-\u9fa5]{1,4})(先生|女士)').firstMatch(text);
  if (nm != null) name = nm.group(1)!;
  // 2) 我叫/名字叫/姓名/名字
  if (name.isEmpty) {
    nm = RegExp(r'(?:我叫|名字叫|姓名|名字)\s*([\u4e00-\u9fa5]{1,4})').firstMatch(text);
    if (nm != null) name = nm.group(1)!;
  }
  // 3) 开头连续汉字（排除关键词）
  if (name.isEmpty) {
    nm = RegExp(r'^[^\d]*([\u4e00-\u9fa5]{1,4?})').firstMatch(text);
    if (nm != null) {
      String candidate = nm.group(1) ?? '';
      // 去掉关键词
      candidate = candidate.replaceAll(RegExp(r'(排盘|八字|出生|大师|您好|你好|我是|我叫|性别|帮我|帮忙|麻烦|农历|男|女)'), '');
      if (candidate.isNotEmpty && candidate.length <= 4) name = candidate;
    }
  }
  // 4) 末尾姓名（如 "...名字叫张十" 或 "...李四"）
  if (name.isEmpty) {
    nm = RegExp(r'(?:名字叫|叫)\s*([\u4e00-\u9fa5]{1,4})\s*$').firstMatch(text);
    if (nm != null) name = nm.group(1)!;
  }
  // 5) 兜底：从原文中提取，去掉所有已知模式后剩余的汉字
  if (name.isEmpty) {
    String rest = text;
    rest = rest.replaceAll(RegExp(r'\d{4}\s*年\s*\d{1,2}\s*月\s*\d{1,2}\s*[日号]?'), '');
    rest = rest.replaceAll(RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}'), '');
    rest = rest.replaceAll(RegExp(r'\d{4,12}'), '');
    rest = rest.replaceAll(RegExp(r'\d{1,2}\s*[点时:]\s*\d{0,2}\s*分?'), '');
    rest = rest.replaceAll(RegExp(r'[子丑寅卯辰巳午未申酉戌亥]时'), '');
    rest = rest.replaceAll(RegExp(r'(凌晨|早上|上午|中午|下午|傍晚|晚上|农历|正月|腊月|冬月)'), '');
    rest = rest.replaceAll(RegExp(r'(初[一二三四五六七八九十]+|廿[一二三四五六七八九]|二十[一二三四五六七八九]?|三十)'), '');
    rest = rest.replaceAll(RegExp(r'(排盘|八字|出生|大师|您好|你好|我叫|我是|名字叫|姓名|名字|性别|帮我|帮忙|看八字|麻烦|先生|女士|男命|女命|请|的|了|吗|呢|吧|啊|哦|哈)'), '');
    rest = rest.replaceAll(RegExp(r'[男女]'), '');
    rest = rest.replaceAll(RegExp(r'[\d\s,，。.：:、\-/（）()]+'), '');
    rest = rest.trim();
    if (rest.isNotEmpty && rest.length <= 4) {
      nm = RegExp(r'[\u4e00-\u9fa5]{1,4}').firstMatch(rest);
      if (nm != null) name = nm.group(0)!;
    }
  }

  // ===== 农历转公历 =====
  if (isLunar && year != null && month != null && day != null) {
    final solar = lunarToSolar(year, month, day);
    if (solar != null) {
      year = solar.year; month = solar.month; day = solar.day;
    }
  }

  return {
    'year': year, 'month': month, 'day': day, 'hour': hour,
    'isMale': isMale, 'name': name, 'isLunar': isLunar,
  };
}

// ============================================================
// 本地数据库
// ============================================================
class BaZiDB {
  static Box get _box => Hive.box('bazi_records');
  static const _uuid = Uuid();

  static String save({
    required String name, required int year, required int month,
    required int day, required int hour, required bool isMale,
  }) {
    final id = _uuid.v4();
    _box.put(id, {
      'id': id, 'name': name, 'year': year, 'month': month,
      'day': day, 'hour': hour, 'isMale': isMale,
      'isFavorite': false, 'createdAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  static List<Map<String, dynamic>> getAll() {
    final list = _box.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
    list.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
    return list;
  }

  static List<Map<String, dynamic>> getFavorites() {
    return getAll().where((r) => r['isFavorite'] == true).toList();
  }

  static void toggleFavorite(String id) {
    final record = _box.get(id);
    if (record != null) {
      final m = Map<String, dynamic>.from(record as Map);
      m['isFavorite'] = !(m['isFavorite'] as bool? ?? false);
      _box.put(id, m);
    }
  }

  static void updateComment(String id, String content) {
    final record = _box.get(id);
    if (record != null) {
      final m = Map<String, dynamic>.from(record as Map);
      m['comment'] = content;
      _box.put(id, m);
    }
  }

  static void updateNotes(String id, Map<String, dynamic> notes) {
    final record = _box.get(id);
    if (record != null) {
      final m = Map<String, dynamic>.from(record as Map);
      m['notes'] = notes;
      _box.put(id, m);
    }
  }

  static void delete(String id) => _box.delete(id);
  static void clearAll() => _box.clear();
}

// ============================================================
// 输入页面 — Apple 风格
// ============================================================
class InputPage extends StatefulWidget {
  const InputPage({super.key});
  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  int _year = 1990, _month = 1, _day = 1, _hour = 12, _minute = 0;
  bool _isMale = true;
  bool _isLunarMode = true;
  String _name = '';
  final _smartCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String? _parseHint;

  String get _dateDisplayStr {
    if (_isLunarMode) {
      final l = solarToLunar(_year, _month, _day);
      return '农历 ${l[0]}年${lunarMonthName(l[1])}月${lunarDayName(l[2])} $_hour:${_minute.toString().padLeft(2, '0')}';
    }
    return '$_year年$_month月$_day日 $_hour:${_minute.toString().padLeft(2, '0')}';
  }

  void _onSmartInput(String text) {
    if (text.trim().isEmpty) { setState(() => _parseHint = null); return; }
    final r = parseInput(text);
    List<String> found = [];
    setState(() {
      if (r['year'] != null) { _year = r['year']; found.add('$_year年'); }
      if (r['month'] != null) { _month = r['month']; found.add('$_month月'); }
      if (r['day'] != null) { _day = r['day']; found.add('$_day日'); }
      if (r['hour'] != null) { _hour = r['hour']; found.add('$_hour时'); }
      if (r['isMale'] != null) { _isMale = r['isMale']; found.add(_isMale ? '男' : '女'); }
      if ((r['name'] as String).isNotEmpty) { _name = r['name']; _nameCtrl.text = _name; found.add(_name); }
      if (r['isLunar'] == true) found.add('(农历已转公历)');
      _parseHint = found.isEmpty ? '未能识别，请检查格式' : '已识别：${found.join(' ')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(children: [
          // 顶栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              Text('八字排盘', style: TextStyle(fontSize: 24, color: kTextColor, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const HistoryPage())),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kTextColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.history_rounded, color: kTextColor, size: 22),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                // 智能输入
                _card([
                  Text('智能识别', style: TextStyle(fontSize: 13, color: kTextColor.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _smartCtrl,
                      style: TextStyle(fontSize: 16, color: kTextColor),
                      decoration: InputDecoration(
                        hintText: '张三 1990年1月1日 12时 男',
                        hintStyle: TextStyle(fontSize: 15, color: kTextColor.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: kTextColor.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _onSmartInput(_smartCtrl.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: kTextColor, borderRadius: BorderRadius.circular(12)),
                        child: Text('识别', style: TextStyle(fontSize: 15, color: kBgColor, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                  if (_parseHint != null) ...[
                    const SizedBox(height: 8),
                    Text(_parseHint!, style: TextStyle(fontSize: 12, color: kTextColor.withValues(alpha: 0.55))),
                  ],
                ]),
                const SizedBox(height: 16),
                // 姓名
                _card([
                  Text('姓名', style: TextStyle(fontSize: 13, color: kTextColor.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    onChanged: (v) => _name = v,
                    style: TextStyle(fontSize: 16, color: kTextColor),
                    decoration: InputDecoration(
                      hintText: '选填',
                      hintStyle: TextStyle(fontSize: 15, color: kTextColor.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: kTextColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // 生辰选择
                _card([
                  Text('生辰', style: TextStyle(fontSize: 13, color: kTextColor.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _showDatePicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: kTextColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(_dateDisplayStr, style: TextStyle(fontSize: 15, color: kTextColor, fontWeight: FontWeight.w500))),
                        Icon(Icons.chevron_right_rounded, color: kTextColor.withValues(alpha: 0.4), size: 20),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // 性别
                _card([
                  Text('性别', style: TextStyle(fontSize: 13, color: kTextColor.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _genderToggle(),
                ]),
                const SizedBox(height: 28),
                // 排盘按钮
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(color: kTextColor, borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: Text('排  盘', style: TextStyle(fontSize: 18, color: kBgColor, fontWeight: FontWeight.w600, letterSpacing: 4)),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
          ),
          ),
        ]),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _genderToggle() {
    return Container(
      decoration: BoxDecoration(
        color: kTextColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _isMale = true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _isMale ? kTextColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('男', style: TextStyle(fontSize: 16, color: _isMale ? kBgColor : kTextColor, fontWeight: FontWeight.w600)),
          ),
        )),
        Expanded(child: GestureDetector(
          onTap: () => setState(() => _isMale = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: !_isMale ? kTextColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('女', style: TextStyle(fontSize: 16, color: !_isMale ? kBgColor : kTextColor, fontWeight: FontWeight.w600)),
          ),
        )),
      ]),
    );
  }

  void _showDatePicker() {
    // If lunar mode, convert current solar to lunar for picker
    int pYear = _year, pMonth = _month, pDay = _day;
    if (_isLunarMode) {
      final l = solarToLunar(_year, _month, _day);
      pYear = l[0]; pMonth = l[1]; pDay = l[2];
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => DatePickerSheet(
        isLunar: _isLunarMode, year: pYear, month: pMonth, day: pDay, hour: _hour, minute: _minute,
        onConfirm: (isLunar, y, m, d, h, min) {
          setState(() {
            _isLunarMode = isLunar;
            if (isLunar) {
              final solar = lunarToSolar(y, m, d);
              if (solar != null) { _year = solar.year; _month = solar.month; _day = solar.day; }
            } else {
              _year = y; _month = m; _day = d;
            }
            _hour = h; _minute = min;
          });
        },
      ),
    );
  }

  void _submit() {
    final dt = DateTime(_year, _month, _day, _hour, _minute);
    final result = calculate(dt, _isMale, name: _name);
    final id = BaZiDB.save(name: _name, year: _year, month: _month, day: _day, hour: _hour, isMale: _isMale);
    Navigator.push(context, CupertinoPageRoute(builder: (_) => ChartPage(result: result, recordId: id)));
  }
}

// ============================================================
// 日期选择器 — 公历/农历 组合滚轮
// ============================================================
const _lunarMonths = ['正月','二月','三月','四月','五月','六月','七月','八月','九月','十月','冬月','腊月'];
const _lunarDays = [
  '初一','初二','初三','初四','初五','初六','初七','初八','初九','初十',
  '十一','十二','十三','十四','十五','十六','十七','十八','十九','二十',
  '廿一','廿二','廿三','廿四','廿五','廿六','廿七','廿八','廿九','三十',
];

class DatePickerSheet extends StatefulWidget {
  final bool isLunar;
  final int year, month, day, hour, minute;
  final void Function(bool isLunar, int year, int month, int day, int hour, int minute) onConfirm;
  const DatePickerSheet({super.key, required this.isLunar, required this.year, required this.month, required this.day, required this.hour, required this.minute, required this.onConfirm});
  @override
  State<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<DatePickerSheet> {
  late int _tab; // 0=农历, 1=公历
  late int _y, _m, _d, _h, _min;
  late FixedExtentScrollController _yC, _mC, _dC, _hC, _minC;
  final _qCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = widget.isLunar ? 0 : 1;
    _y = widget.year; _m = widget.month; _d = widget.day; _h = widget.hour; _min = widget.minute;
    _yC = FixedExtentScrollController(initialItem: _y - 1900);
    _mC = FixedExtentScrollController(initialItem: _m - 1);
    _dC = FixedExtentScrollController(initialItem: (_d - 1).clamp(0, 29));
    _hC = FixedExtentScrollController(initialItem: _h);
    _minC = FixedExtentScrollController(initialItem: _min);
  }

  @override
  void dispose() { _yC.dispose(); _mC.dispose(); _dC.dispose(); _hC.dispose(); _minC.dispose(); _qCtrl.dispose(); super.dispose(); }

  bool get _isLunar => _tab == 0;

  void _jumpAll() {
    _yC.jumpToItem((_y - 1900).clamp(0, 200));
    _mC.jumpToItem((_m - 1).clamp(0, 11));
    _dC.jumpToItem((_d - 1).clamp(0, _isLunar ? 29 : 30));
    _hC.jumpToItem(_h.clamp(0, 23));
    _minC.jumpToItem(_min.clamp(0, 59));
    setState(() {});
  }

  void _setToday() {
    final now = DateTime.now();
    if (_isLunar) {
      final l = solarToLunar(now.year, now.month, now.day);
      _y = l[0]; _m = l[1]; _d = l[2];
    } else {
      _y = now.year; _m = now.month; _d = now.day;
    }
    _h = now.hour; _min = now.minute;
    _jumpAll();
  }

  void _onQuickInput() {
    final t = _qCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (t.length >= 8) {
      _y = int.parse(t.substring(0, 4)); _m = int.parse(t.substring(4, 6)); _d = int.parse(t.substring(6, 8));
      if (t.length >= 10) _h = int.parse(t.substring(8, 10));
      if (t.length >= 12) _min = int.parse(t.substring(10, 12));
      _jumpAll();
    }
  }

  void _switchTab(int i) {
    if (i == _tab) return;
    if (i == 0 && _tab == 1) {
      final l = solarToLunar(_y, _m, _d);
      _y = l[0]; _m = l[1]; _d = l[2];
    } else if (i == 1 && _tab == 0) {
      final s = lunarToSolar(_y, _m, _d);
      if (s != null) { _y = s.year; _m = s.month; _d = s.day; }
    }
    _tab = i;
    _jumpAll();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: kBgColor, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, decoration: BoxDecoration(color: kTextColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        // 今 + tabs + X
        Row(children: [
          GestureDetector(onTap: _setToday, child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: kTextColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('今', style: TextStyle(fontSize: 14, color: kTextColor, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 12),
          Expanded(child: Container(
            decoration: BoxDecoration(color: kTextColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(22)),
            child: Row(children: List.generate(2, (i) {
              const labels = ['农历', '公历'];
              return Expanded(child: GestureDetector(
                onTap: () => _switchTab(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(color: _tab == i ? kTextColor : Colors.transparent, borderRadius: BorderRadius.circular(22)),
                  alignment: Alignment.center,
                  child: Text(labels[i], style: TextStyle(fontSize: 13, color: _tab == i ? kBgColor : kTextColor, fontWeight: FontWeight.w600)),
                ),
              ));
            })),
          )),
          const SizedBox(width: 12),
          GestureDetector(onTap: () => Navigator.pop(context), child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: kTextColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.close, color: kTextColor, size: 18),
          )),
        ]),
        const SizedBox(height: 12),
        // 快捷输入
        Row(children: [
          Expanded(child: TextField(
            controller: _qCtrl,
            style: TextStyle(fontSize: 14, color: kTextColor),
            decoration: InputDecoration(
              hintText: '输入出生年月日时分(格式199303270255)',
              hintStyle: TextStyle(fontSize: 12, color: kTextColor.withValues(alpha: 0.3)),
              filled: true, fillColor: kTextColor.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          )),
          const SizedBox(width: 8),
          GestureDetector(onTap: _onQuickInput, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: kTextColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('确定', style: TextStyle(fontSize: 13, color: kTextColor, fontWeight: FontWeight.w600)),
          )),
        ]),
        const SizedBox(height: 8),
        // 列头
        Row(children: ['年','月','日','时','分'].map((h) => Expanded(child: Center(
          child: Text(h, style: TextStyle(fontSize: 13, color: kTextColor.withValues(alpha: 0.45), fontWeight: FontWeight.w600)),
        ))).toList()),
        // 滚轮
        SizedBox(height: 200, child: Stack(children: [
          // 选中行高亮
          Center(child: Container(
            height: 44, margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: kTextColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
          )),
          Row(children: [
            _wheel(_yC, 201, (i) => '${1900 + i}', (i) { _y = 1900 + i; }),
            _wheel(_mC, 12, (i) => _isLunar ? _lunarMonths[i] : '${i + 1}'.padLeft(2, '0'), (i) { _m = i + 1; }),
            _wheel(_dC, _isLunar ? 30 : 31, (i) => _isLunar ? _lunarDays[i] : '${i + 1}'.padLeft(2, '0'), (i) { _d = i + 1; }),
            _wheel(_hC, 24, (i) => '$i'.padLeft(2, '0'), (i) { _h = i; }),
            _wheel(_minC, 60, (i) => '$i'.padLeft(2, '0'), (i) { _min = i; }),
          ]),
        ])),
        const SizedBox(height: 16),
        // 确定
        GestureDetector(
          onTap: () { widget.onConfirm(_isLunar, _y, _m, _d, _h, _min); Navigator.pop(context); },
          child: Container(
            height: 52,
            decoration: BoxDecoration(color: kTextColor, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text('确定', style: TextStyle(fontSize: 17, color: kBgColor, fontWeight: FontWeight.w600)),
          ),
        ),
      ])),
    );
  }

  Widget _wheel(FixedExtentScrollController ctrl, int count, String Function(int) label, void Function(int) onChanged) {
    return Expanded(child: ListWheelScrollView.useDelegate(
      controller: ctrl, itemExtent: 44, physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) => setState(() => onChanged(i)),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (ctx, i) {
          bool sel = ctrl.hasClients && ctrl.selectedItem == i;
          return Center(child: Text(label(i), style: TextStyle(
            fontSize: sel ? 20 : 14,
            color: sel ? kTextColor : kTextColor.withValues(alpha: 0.3),
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          )));
        },
      ),
    ));
  }
}

// ============================================================
// 历史记录页 — Apple 风格
// ============================================================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _showFavOnly = false;

  List<Map<String, dynamic>> get _records => _showFavOnly ? BaZiDB.getFavorites() : BaZiDB.getAll();

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgColor,
        title: const Text('清除所有记录', style: TextStyle(color: kTextColor)),
        content: const Text('确定要删除所有历史记录吗？此操作不可恢复。', style: TextStyle(color: kTextColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              BaZiDB.clearAll();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(children: [
          // 顶栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: kTextColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: kTextColor, size: 18),
                ),
              ),
              const SizedBox(width: 16),
              Text('历史记录', style: TextStyle(fontSize: 20, color: kTextColor, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmClearAll(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: kTextColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.delete_sweep_rounded, color: kTextColor, size: 20),
                ),
              ),
            ]),
          ),
          // Tab 切换
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              decoration: BoxDecoration(color: kTextColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                _tab('全部', !_showFavOnly, () => setState(() => _showFavOnly = false)),
                _tab('收藏', _showFavOnly, () => setState(() => _showFavOnly = true)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          // 列表
          Expanded(
            child: records.isEmpty
              ? Center(child: Text(_showFavOnly ? '暂无收藏' : '暂无记录', style: TextStyle(fontSize: 15, color: kTextColor.withValues(alpha: 0.4))))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: records.length,
                  itemBuilder: (ctx, i) => _recordCard(records[i]),
                ),
          ),
        ]),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? kTextColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 14, color: active ? kBgColor : kTextColor, fontWeight: FontWeight.w600)),
      ),
    ));
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final id = record['id'] as String;
    final name = record['name'] as String? ?? '';
    final year = record['year'] as int;
    final month = record['month'] as int;
    final day = record['day'] as int;
    final hour = record['hour'] as int;
    final isMale = record['isMale'] as bool;
    final isFav = record['isFavorite'] as bool? ?? false;
    final comment = record['comment'] as String? ?? '';
    final displayName = name.isNotEmpty ? name : '${isMale ? "男" : "女"} $year-$month-$day';

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      onDismissed: (_) { BaZiDB.delete(id); setState(() {}); },
      child: GestureDetector(
        onTap: () {
          final dt = DateTime(year, month, day, hour);
          final result = calculate(dt, isMale, name: name);
          final comment = record['comment'] as String? ?? '';
          final notes = record['notes'] != null ? Map<String, dynamic>.from(record['notes'] as Map) : <String, dynamic>{};
          Navigator.push(context, CupertinoPageRoute(builder: (_) => ChartPage(result: result, recordId: id, initialComment: comment, initialNotes: notes)));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayName, style: TextStyle(fontSize: 16, color: kTextColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('$year年$month月$day日 $hour时 ${isMale ? "男" : "女"}',
                style: TextStyle(fontSize: 13, color: kTextColor.withValues(alpha: 0.5))),
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(comment.length > 30 ? '${comment.substring(0, 30)}...' : comment,
                  style: TextStyle(fontSize: 12, color: kTextColor.withValues(alpha: 0.4), fontStyle: FontStyle.italic),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ])),
            GestureDetector(
              onTap: () { BaZiDB.toggleFavorite(id); setState(() {}); },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFav ? const Color(0xFFE8A838) : kTextColor.withValues(alpha: 0.3), size: 24),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// 排盘结果页 — 传统大师纸
// 从右到左：祈福堂 → 四柱 → 大运 → 相命同参 → 批流年
// ============================================================

  class ChartPage extends StatefulWidget {
  final BaZiResult result;
  final String? recordId;
  final String? initialComment;
  final Map<String, dynamic>? initialNotes;
  const ChartPage({super.key, required this.result, this.recordId, this.initialComment, this.initialNotes});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  final GlobalKey _repaintKey = GlobalKey();
  late TextEditingController _commentController;
  bool _isCapturing = false;
  late Map<String, dynamic> _notes;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.initialComment ?? '');
    _commentController.addListener(_onCommentChanged);
    _notes = Map<String, dynamic>.from(widget.initialNotes ?? {});
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    if (widget.recordId != null) {
      BaZiDB.updateComment(widget.recordId!, _commentController.text);
    }
  }

  void _saveNotes() {
    if (widget.recordId != null) {
      BaZiDB.updateNotes(widget.recordId!, _notes);
    }
  }

  void _showNoteDialog(String key, String title, {bool hasScore = false}) {
    final existing = _notes[key] as Map<String, dynamic>? ?? {};
    final textCtrl = TextEditingController(text: existing['text'] as String? ?? '');
    final scoreCtrl = TextEditingController(text: existing['score']?.toString() ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: kBgColor, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: kTextColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor)),
            const SizedBox(height: 16),
            if (hasScore) ...[
              TextField(controller: scoreCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 16, color: kTextColor),
                decoration: InputDecoration(hintText: '岁数', hintStyle: TextStyle(fontSize: 14, color: kTextColor.withOpacity(0.3)), filled: true, fillColor: kTextColor.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
              const SizedBox(height: 12),
            ],
            TextField(controller: textCtrl, maxLines: 4, style: const TextStyle(fontSize: 16, color: kTextColor),
              decoration: InputDecoration(hintText: '输入批注...', hintStyle: TextStyle(fontSize: 14, color: kTextColor.withOpacity(0.3)), filled: true, fillColor: kTextColor.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(height: 48, decoration: BoxDecoration(color: kTextColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: const Text('取消', style: TextStyle(fontSize: 16, color: kTextColor, fontWeight: FontWeight.w600))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(onTap: () { setState(() { _notes[key] = {'text': textCtrl.text, if (hasScore) 'score': scoreCtrl.text}; }); _saveNotes(); Navigator.pop(ctx); }, child: Container(height: 48, decoration: BoxDecoration(color: kTextColor, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text('保存', style: TextStyle(fontSize: 16, color: kBgColor, fontWeight: FontWeight.w600))))),
            ]),
          ])),
        ),
      ),
    );
  }

  Widget _vText(String text, {double size = 16, FontWeight weight = FontWeight.normal, Color color = kTextColor, double height = 1.5}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: text.split('').map((c) => Text(c,
        style: TextStyle(fontSize: size, fontWeight: weight, color: color, height: height),
      )).toList(),
    );
  }

  String _toChinese(int i) {
    const digits = ['零','一','二','三','四','五','六','七','八','九'];
    if (i < 10) return digits[i];
    if (i < 20) return '十${i%10==0?'':digits[i%10]}';
    if (i < 100) return '${digits[i~/10]}十${i%10==0?'':digits[i%10]}';
    return '$i';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 800),
                color: kBgColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. 祈福堂
                    Stack(
                      children: [
                        if (!_isCapturing)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextColor, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        Center(child: Text('祈福堂', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: kTextColor, letterSpacing: 4))),
                        if (!_isCapturing)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.share_rounded, color: kTextColor, size: 22),
                                  onPressed: () => _shareChart(context),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.save_alt, color: kTextColor),
                                  onPressed: () => _saveToGallery(context),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 2. 主体表格与信息
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Center: Si Zhu Table
                          Expanded(child: _buildSiZhuTable()),
                          const SizedBox(width: 8),

                          // Right: Qi Fu Info
                          _buildSideBox(_buildQiFuInfoContent()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 3. 大运
                    _buildDaYunSection(),
                    const SizedBox(height: 20),

                    // 4. 批流年
                    _buildPiLiuNianInput(),
                    const SizedBox(height: 24),

                    // 5. 相命同参（横排）
                    Center(child: Text(
                      '相 命 同 参 · 有 错 携 回 再 评',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor.withOpacity(0.6), letterSpacing: 2),
                    )),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideBox(Widget child) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kTextColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: child,
    );
  }

  Widget _buildXiangMingContent() {
    const chars = ['相', '命', '同', '参', '有', '错', '携', '回', '再', '评'];
    const double charSize = 20;
    const double rowGap = charSize;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < chars.length; i++) ...[
              Text(chars[i], style: const TextStyle(fontSize: charSize, fontWeight: FontWeight.bold, color: kTextColor)),
              if (i < chars.length - 1) const SizedBox(height: rowGap),
            ],
          ],
        ),
        const SizedBox(width: 8),
        // Ruled Strip
        Container(
          width: 20,
          decoration: BoxDecoration(border: Border(left: BorderSide(color: kTextColor, width: 1))),
          child: Column(
            children: List.generate(12, (index) => Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kTextColor, width: 1))),
              ),
            )),
          ),
        ),
      ],
    );
  }

  Widget _buildQiFuInfoContent() {
    final r = widget.result;
    String genderStr = r.isMale ? '乾造' : '坤造';
    int nominalAge = DateTime.now().year - r.birthDt.year + 1;
    String ageStr = '${_toChinese(nominalAge)}岁';
    
    final lunar = solarToLunar(r.birthDt.year, r.birthDt.month, r.birthDt.day);
    String lunarStr = '${lunarMonthName(lunar[1])}月${lunarDayName(lunar[2])}';
    int h = r.birthDt.hour;
    int zhiIdx;
    if (h == 23 || h == 0) { zhiIdx = 0; } else { zhiIdx = ((h + 1) ~/ 2) % 12; }
    String shiChen = '${shiChenName[zhiIdx]}时';
    
    String dateStr = '$lunarStr$shiChen';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Original Info Column
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _vText(genderStr, size: 24, weight: FontWeight.bold),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _vText(ageStr, size: 20),
            ),
            _vText(dateStr, size: 18),
            _vText('建生大吉', size: 20, weight: FontWeight.bold),
          ],
        ),
        if (r.name.isNotEmpty) ...[
          const SizedBox(width: 8),
          // Name Column (Right side)
          _vText(r.name, size: 24, weight: FontWeight.bold, height: 1.2),
        ],
      ],
    );
  }

  Widget _buildSiZhuTable() {
    final borderSide = BorderSide(color: kTextColor, width: 1);
    
    // Ming Gong Calculation
    final r = widget.result;
    // Ming Zhi: (4 - monthZhi + hourZhi) % 12. Note: indices 0-11.
    // MonthZhi is r.monthZhi (which is Solar Term Month). 
    // HourZhi is r.hourZhi.
    int mingZhiIdx = (4 - r.monthZhi + r.hourZhi + 12) % 12;
    // Ming Gan: Year Gan -> Wu Hu Dun.
    // Base for Yin (2) is (yearGan % 5) * 2 + 2.
    int baseGan = (r.yearGan % 5) * 2 + 2;
    int ganSteps = (mingZhiIdx - 2 + 12) % 12;
    int mingGanIdx = (baseGan + ganSteps) % 10;
    
    String nyMing = getNaYin(mingGanIdx, mingZhiIdx);
    String nyYear = getNaYin(r.yearGan, r.yearZhi);
    String nyMonth = getNaYin(r.monthGan, r.monthZhi);
    String nyDay = getNaYin(r.dayGan, r.dayZhi);
    String nyHour = getNaYin(r.hourGan, r.hourZhi);

    const tsTiny = TextStyle(fontSize: 12, color: kTextColor);

    // Na Yin Row Items (5 items)
    // Order: Ming, Hour, Day, Month, Year (Left to Right)
    // Or depends on layout. Usually Year is Rightmost.
    // So Visual Left->Right: Ming, Hour, Day, Month, Year.
    List<String> naYins = ['土', '火', '水', '木', '金'];

    return Container(
      decoration: BoxDecoration(border: Border.all(color: kTextColor, width: 1)),
      child: Column(
        children: [
           // Row 1: Na Yin (5 items) - Outside Table to allow 5 columns vs 4
           Container(
             height: 40,
             decoration: BoxDecoration(border: Border(bottom: borderSide)),
             child: Row(
               children: naYins.map((ny) => Expanded(
                 child: Container(
                   decoration: BoxDecoration(
                     border: (naYins.indexOf(ny) < 4) ? Border(right: borderSide) : null,
                   ),
                   alignment: Alignment.center,
                   padding: const EdgeInsets.all(2),
                   child: FittedBox(child: Text(ny, style: tsTiny)),
                 ),
               )).toList(),
             ),
           ),
           // The Table (Stars, Headers, Pillars)
           _buildInnerTable(),
           // The Separator
           Container(height: 1, color: kTextColor),
           // Li Ming Section
           Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isCapturing ? null : () => _showNoteDialog('mingGong', '立命批注'),
                  child: _vText('立命', size: 32, weight: FontWeight.w900),
                ),
                if ((_notes['mingGong'] as Map<String, dynamic>?)?['text']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text((_notes['mingGong'] as Map)['text'], style: TextStyle(fontSize: 15, color: kTextColor.withOpacity(0.5)), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _isCapturing ? null : () => _showNoteDialog('xiaoXian', '小限批注'),
                      child: Column(children: [
                        Text('小限', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kTextColor)),
                        if ((_notes['xiaoXian'] as Map<String, dynamic>?)?['text']?.toString().isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text((_notes['xiaoXian'] as Map)['text'], style: TextStyle(fontSize: 14, color: kTextColor.withOpacity(0.5))),
                        ],
                      ]),
                    ),
                    const SizedBox(width: 40),
                    GestureDetector(
                      onTap: _isCapturing ? null : () => _showNoteDialog('daXian', '大限批注'),
                      child: Column(children: [
                        Text('大限', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kTextColor)),
                        if ((_notes['daXian'] as Map<String, dynamic>?)?['text']?.toString().isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text((_notes['daXian'] as Map)['text'], style: TextStyle(fontSize: 14, color: kTextColor.withOpacity(0.5))),
                        ],
                      ]),
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

  // Helper for inner table
  Widget _buildInnerTable() {
    final r = widget.result;

    List<String> yearSS = getZhiShiShenList(r.dayGan, r.yearZhiStr);
    List<String> monthSS = getZhiShiShenList(r.dayGan, r.monthZhiStr);
    List<String> daySS = getZhiShiShenList(r.dayGan, r.dayZhiStr);
    List<String> hourSS = getZhiShiShenList(r.dayGan, r.hourZhiStr);

    String hourGod = getShiShenShort(r.dayGan, r.hourGan);
    String dayGod = '日元';
    String monthGod = getShiShenShort(r.dayGan, r.monthGan);
    String yearGod = getShiShenShort(r.dayGan, r.yearGan);

    const tsTiny = TextStyle(fontSize: 14, color: kTextColor);
    const tsHeader = TextStyle(fontSize: 22, color: kTextColor, fontWeight: FontWeight.bold);

    Widget buildCol(String gan, String zhi, List<String> hGods) {
       return Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           const SizedBox(height: 8),
           Text(gan, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: kTextColor)),
           const SizedBox(height: 8),
           Text(zhi, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: kTextColor)),
           const SizedBox(height: 8),
           Column(children: hGods.map((e) => Text(e, style: tsTiny)).toList()),
           const SizedBox(height: 8),
         ],
       );
    }
    
    final borderSide = BorderSide(color: kTextColor, width: 1);

    return Table(
        border: TableBorder(
           verticalInside: borderSide,
           horizontalInside: borderSide,
           top: BorderSide.none, // Already handled by container
           bottom: BorderSide.none,
           left: BorderSide.none,
           right: BorderSide.none,
        ),
        columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth()},
        children: [
          // Row 1: ★信士★
          TableRow(children: const [
             Center(child: Padding(padding: EdgeInsets.all(8), child: Text('★', style: TextStyle(fontSize: 22, color: kTextColor)))),
             Center(child: Padding(padding: EdgeInsets.all(8), child: Text('信', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kTextColor)))),
             Center(child: Padding(padding: EdgeInsets.all(8), child: Text('士', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kTextColor)))),
             Center(child: Padding(padding: EdgeInsets.all(8), child: Text('★', style: TextStyle(fontSize: 22, color: kTextColor)))),
          ]),
          // Row 2: 时日月年
          TableRow(children: [
             Center(child: Padding(padding: const EdgeInsets.all(8), child: Text('时', style: tsHeader))),
             Center(child: Padding(padding: const EdgeInsets.all(8), child: Text('日', style: tsHeader))),
             Center(child: Padding(padding: const EdgeInsets.all(8), child: Text('月', style: tsHeader))),
             Center(child: Padding(padding: const EdgeInsets.all(8), child: Text('年', style: tsHeader))),
          ]),
          // Row 3: 主星（十神）
          TableRow(children: [
             Center(child: Padding(padding: const EdgeInsets.all(6), child: Text(hourGod, style: TextStyle(fontSize: 16, color: kTextColor.withOpacity(0.7), fontWeight: FontWeight.w600)))),
             Center(child: Padding(padding: const EdgeInsets.all(6), child: Text(dayGod, style: TextStyle(fontSize: 16, color: kTextColor.withOpacity(0.7), fontWeight: FontWeight.w600)))),
             Center(child: Padding(padding: const EdgeInsets.all(6), child: Text(monthGod, style: TextStyle(fontSize: 16, color: kTextColor.withOpacity(0.7), fontWeight: FontWeight.w600)))),
             Center(child: Padding(padding: const EdgeInsets.all(6), child: Text(yearGod, style: TextStyle(fontSize: 16, color: kTextColor.withOpacity(0.7), fontWeight: FontWeight.w600)))),
          ]),
          // Row 4: Pillars
          TableRow(children: [
             buildCol(r.hourGanStr, r.hourZhiStr, hourSS),
             buildCol(r.dayGanStr, r.dayZhiStr, daySS),
             buildCol(r.monthGanStr, r.monthZhiStr, monthSS),
             buildCol(r.yearGanStr, r.yearZhiStr, yearSS),
          ]),
        ],
    );
  }

  Widget _buildDaYunSection() {
    final list = widget.result.daYunList;
    final dayGan = widget.result.dayGan;
    final borderSide = BorderSide(color: kTextColor, width: 1);

    bool hasAnyNote = false;
    for (int i = 0; i < list.length; i++) {
      final n = _notes['daYun_$i'] as Map<String, dynamic>?;
      if (n != null && ((n['score']?.toString().isNotEmpty == true) || (n['text']?.toString().isNotEmpty == true))) { hasAnyNote = true; break; }
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: kTextColor, width: 1)),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(border: Border(bottom: borderSide)),
          child: const Center(child: Text('大  运', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor)))),
        // Ten Gods row
        Container(decoration: BoxDecoration(border: Border(bottom: borderSide)),
          child: Row(children: List.generate(list.length, (i) {
            String god = getShiShenShort(dayGan, list[i][0]);
            return Expanded(child: Container(decoration: i < list.length - 1 ? BoxDecoration(border: Border(right: borderSide)) : null, padding: const EdgeInsets.symmetric(vertical: 6), alignment: Alignment.center, child: Text(god, style: TextStyle(fontSize: 14, color: kTextColor.withOpacity(0.6)))));
          }))),
        // Tian Gan row
        Container(decoration: BoxDecoration(border: Border(bottom: borderSide)),
          child: Row(children: List.generate(list.length, (i) {
            return Expanded(child: Container(decoration: i < list.length - 1 ? BoxDecoration(border: Border(right: borderSide)) : null, padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center, child: Text(tianGan[list[i][0]], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.red))));
          }))),
        // Di Zhi row
        Container(decoration: hasAnyNote ? BoxDecoration(border: Border(bottom: borderSide)) : null,
          child: Row(children: List.generate(list.length, (i) {
            final zhi = list[i][1];
            return Expanded(child: GestureDetector(
              onTap: _isCapturing ? null : () => _showNoteDialog('daYun_$i', '${tianGan[list[i][0]]}${diZhi[zhi]} 大运批注', hasScore: true),
              child: Container(decoration: i < list.length - 1 ? BoxDecoration(border: Border(right: borderSide)) : null, padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center, child: Text(diZhi[zhi], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.red)))));
          }))),
        // Notes row
        if (hasAnyNote)
          Row(children: List.generate(list.length, (i) {
            final n = _notes['daYun_$i'] as Map<String, dynamic>? ?? {};
            final score = n['score']?.toString() ?? '';
            final text = n['text']?.toString() ?? '';
            return Expanded(child: GestureDetector(
              onTap: _isCapturing ? null : () => _showNoteDialog('daYun_$i', '${tianGan[list[i][0]]}${diZhi[list[i][1]]} 大运批注', hasScore: true),
              child: Container(decoration: i < list.length - 1 ? BoxDecoration(border: Border(right: borderSide)) : null, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2), alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (score.isNotEmpty) Text(score, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  if (text.isNotEmpty) Text(text, style: TextStyle(fontSize: 12, color: kTextColor.withOpacity(0.5)), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ]))));
          })),
      ]),
    );
  }

  Widget _buildPiLiuNianInput() {
    final comment = _commentController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('批流年', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kTextColor)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isCapturing ? null : _showPiLiuNianDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: kTextColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              comment.isNotEmpty ? comment : '点击输入流年批语...',
              style: TextStyle(fontSize: 18, color: comment.isNotEmpty ? kTextColor : kTextColor.withOpacity(0.3)),
            ),
          ),
        ),
      ],
    );
  }

  void _showPiLiuNianDialog() {
    final ctrl = TextEditingController(text: _commentController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: kBgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: kTextColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('批流年', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                maxLines: 8,
                autofocus: true,
                style: const TextStyle(fontSize: 18, color: kTextColor),
                decoration: InputDecoration(
                  hintText: '输入流年批语...',
                  hintStyle: TextStyle(fontSize: 16, color: kTextColor.withOpacity(0.3)),
                  filled: true,
                  fillColor: kTextColor.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(color: kTextColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: const Text('取消', style: TextStyle(fontSize: 16, color: kTextColor, fontWeight: FontWeight.w600)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () {
                    _commentController.text = ctrl.text;
                    setState(() {});
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(color: kTextColor, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text('保存', style: TextStyle(fontSize: 16, color: kBgColor, fontWeight: FontWeight.w600)),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _captureImage() async {
    setState(() => _isCapturing = true);
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _shareChart(BuildContext context) async {
    try {
      final bytes = await _captureImage();
      if (bytes == null) return;
      final name = widget.result.name.isNotEmpty ? widget.result.name : '八字排盘';
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: '$name.png', mimeType: 'image/png')],
        text: '$name 八字排盘',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分享失败: $e')));
      }
    }
  }

  Future<void> _saveToGallery(BuildContext context) async {
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web 平台请使用浏览器截图保存（Cmd+Shift+4）')),
        );
      }
      return;
    }
    try {
      final bytes = await _captureImage();
      if (bytes == null) return;
      final res = await ImageGallerySaver.saveImage(bytes, quality: 100, name: 'bazi_${DateTime.now().millisecondsSinceEpoch}');
      if (context.mounted) {
        final success = res['isSuccess'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '八字纸已保存到相册' : '保存失败，请重试')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }
}
