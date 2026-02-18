// Precise JD verification
const List<String> tianGan = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const List<String> diZhi = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

List<int> getDayPillarOld(DateTime dt) {
  int y = dt.year, m = dt.month, d = dt.day;
  if (m <= 2) { y -= 1; m += 12; }
  int a2 = y ~/ 100;
  int b2 = 2 - a2 + a2 ~/ 4;
  int jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b2 - 1524;
  int idx = (jd - 11) % 60;
  if (idx < 0) idx += 60;
  return [idx % 10, idx % 12];
}

void main() {
  // Use the most reliable method: count days from a known anchor
  // 1949-10-01 = 甲子日 (甲=0, 子=0, 60甲子 idx=0) — universally agreed
  DateTime anchor = DateTime(1949, 10, 1);
  int anchorIdx60 = 0; // 甲子

  // Verify a bunch of dates by counting from anchor
  final testDates = [
    [2000, 1, 1],
    [2008, 8, 8],
    [1990, 3, 15],
    [1978, 1, 5],
    [1978, 1, 6],
    [2024, 2, 10],
    [1985, 7, 22],
    [2005, 2, 3],
    [1993, 12, 8],
  ];

  print('基准: 1949-10-01 = 甲子日\n');
  print('日期          | 天数差 | 倒推法      | 公式法      | 匹配?');
  print('-' * 65);

  bool allMatch = true;
  for (var td in testDates) {
    DateTime dt = DateTime(td[0], td[1], td[2]);
    int daysDiff = dt.difference(anchor).inDays;
    int countIdx = (anchorIdx60 + daysDiff) % 60;
    if (countIdx < 0) countIdx += 60;
    String countGZ = '${tianGan[countIdx % 10]}${diZhi[countIdx % 12]}';

    var dp = getDayPillarOld(dt);
    String formulaGZ = '${tianGan[dp[0]]}${diZhi[dp[1]]}';

    bool match = countGZ == formulaGZ;
    if (!match) allMatch = false;
    print('${td[0]}-${td[1].toString().padLeft(2,"0")}-${td[2].toString().padLeft(2,"0")}  | ${daysDiff.toString().padLeft(6)} | $countGZ        | $formulaGZ        | ${match ? "✓" : "✗ ← 错误!"}');
  }

  if (!allMatch) {
    print('\n发现不匹配! 尝试不同 offset 值...');
    // Test what offset makes ALL dates match
    for (int testOffset = 0; testOffset <= 60; testOffset++) {
      bool ok = true;
      for (var td in testDates) {
        DateTime dt = DateTime(td[0], td[1], td[2]);
        int daysDiff = dt.difference(anchor).inDays;
        int countIdx = (anchorIdx60 + daysDiff) % 60;
        if (countIdx < 0) countIdx += 60;

        int y = dt.year, m = dt.month, d = dt.day;
        if (m <= 2) { y -= 1; m += 12; }
        int a2 = y ~/ 100;
        int b2 = 2 - a2 + a2 ~/ 4;
        int jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b2 - 1524;
        int idx = (jd - testOffset) % 60;
        if (idx < 0) idx += 60;

        if (idx % 10 != countIdx % 10 || idx % 12 != countIdx % 12) {
          ok = false;
          break;
        }
      }
      if (ok) {
        print('offset=$testOffset 使所有日期匹配!');
      }
    }
  } else {
    print('\n所有日期匹配 ✓');
  }
}
