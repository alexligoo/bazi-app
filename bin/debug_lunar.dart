// Debug script to trace solarToLunar issues
import 'dart:io';

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

int _lunarMonthDays(int year, int month) =>
    (_lunarInfo[year - 1900] & (0x10000 >> month)) != 0 ? 30 : 29;
int _lunarLeapMonth(int year) => _lunarInfo[year - 1900] & 0xf;
int _lunarLeapDays(int year) {
  if (_lunarLeapMonth(year) == 0) return 0;
  return (_lunarInfo[year - 1900] & 0x10000) != 0 ? 30 : 29;
}
int _lunarYearDays(int year) {
  int sum = 348;
  for (int i = 0x8000; i > 0x8; i >>= 1) {
    sum += (_lunarInfo[year - 1900] & i) != 0 ? 1 : 0;
  }
  return sum + _lunarLeapDays(year);
}

// Original buggy version
List<int> solarToLunarOld(int sy, int sm, int sd) {
  DateTime baseDate = DateTime(1900, 1, 31);
  DateTime solarDate = DateTime(sy, sm, sd);
  int offset = solarDate.difference(baseDate).inDays;

  int lunarYear = 1900;
  int yearDays;
  for (lunarYear = 1900; lunarYear < 2101 && offset > 0; lunarYear++) {
    yearDays = _lunarYearDays(lunarYear);
    offset -= yearDays;
  }
  if (offset < 0) {
    offset += _lunarYearDays(--lunarYear);
  }

  int leapMonth = _lunarLeapMonth(lunarYear);
  bool isLeap = false;
  int lunarMonth = 1, lunarDay;

  for (int i = 1; i < 13 && offset > 0; i++) {
    if (leapMonth > 0 && i == (leapMonth + 1) && !isLeap) {
      --i;
      isLeap = true;
      int leapDays = _lunarLeapDays(lunarYear);
      if (offset < leapDays) break;
      offset -= leapDays;
      isLeap = false;
    } else {
      int mDays = _lunarMonthDays(lunarYear, i);
      if (offset < mDays) break;
      offset -= mDays;
    }
    lunarMonth = i + 1;
  }
  lunarDay = offset + 1;

  return [lunarYear, lunarMonth, lunarDay, isLeap ? 1 : 0];
}

// Fixed version
List<int> solarToLunarNew(int sy, int sm, int sd) {
  DateTime baseDate = DateTime(1900, 1, 31);
  DateTime solarDate = DateTime(sy, sm, sd);
  int offset = solarDate.difference(baseDate).inDays;

  // Find lunar year
  int lunarYear = 1900;
  for (; lunarYear < 2101; lunarYear++) {
    int yDays = _lunarYearDays(lunarYear);
    if (offset < yDays) break;
    offset -= yDays;
  }

  // Find lunar month
  int leapMonth = _lunarLeapMonth(lunarYear);
  int lunarMonth = 1;
  bool isLeapMonth = false;

  for (int i = 1; i <= 12; i++) {
    // Check regular month i
    int mDays = _lunarMonthDays(lunarYear, i);
    if (offset < mDays) {
      lunarMonth = i;
      break;
    }
    offset -= mDays;

    // Check leap month after month i
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

void main() {
  // Test cases
  final tests = [
    [2005, 2, 3],   // Example 8: should be ~腊月廿四 of 2004
    [1993, 12, 8],  // Example 14: should be ~十月廿五 of 1993
    [1990, 3, 15],  // Example 1: should be 二月十九 of 1990
    [1985, 7, 22],  // Example 2
    [2000, 10, 1],  // Example 4
    [1995, 5, 18],  // Example 6
  ];

  for (var t in tests) {
    var old = solarToLunarOld(t[0], t[1], t[2]);
    var nw = solarToLunarNew(t[0], t[1], t[2]);
    print('公历 ${t[0]}-${t[1].toString().padLeft(2,'0')}-${t[2].toString().padLeft(2,'0')}:');
    print('  旧算法: ${old[0]}年${lunarMonthName(old[1])}月${lunarDayName(old[2])} (闰:${old[3]})');
    print('  新算法: ${nw[0]}年${lunarMonthName(nw[1])}月${lunarDayName(nw[2])} (闰:${nw[3]})');
    print('');
  }
}
