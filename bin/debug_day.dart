// Verify day pillar JD formula against known references
// and check 23:00 hour logic consistency

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

List<int> getHourPillar(int hour, int dayGanIdx) {
  int zhiIdx;
  if (hour == 23 || hour == 0) { zhiIdx = 0; } else { zhiIdx = ((hour + 1) ~/ 2) % 12; }
  int startGan = (dayGanIdx % 5) * 2;
  return [(startGan + zhiIdx) % 10, zhiIdx];
}

void main() {
  // Known reference dates (from万年历/standard calendar):
  // 2024-01-01 = 甲子日 (widely verified)
  // 1990-03-15 = ? (need to verify)
  // 1978-01-05 = ? (Example 3, 23:00 case)

  print('=== 日柱儒略日公式验证 ===\n');

  // Standard reference: 2024-01-01 is 甲子日 (verified from multiple sources)
  // Actually let me use a well-known reference:
  // 2000-01-01 (Saturday) = 戊午日 (widely documented)

  final knownDates = [
    // [year, month, day, expected_gan_idx, expected_zhi_idx, description]
    [2000, 1, 1, '戊午', '2000-01-01 标准参照'],
    [1900, 1, 1, '甲戌', '1900-01-01 标准参照'],
    [1990, 3, 15, '?', '1990-03-15 第1例'],
    [1978, 1, 5, '?', '1978-01-05 第3例(非23点调整)'],
    [1978, 1, 6, '?', '1978-01-06 第3例(23点调整后)'],
  ];

  for (var kd in knownDates) {
    int y = kd[0] as int, m = kd[1] as int, d = kd[2] as int;
    var dp = getDayPillarOld(DateTime(y, m, d));
    String gz = '${tianGan[dp[0]]}${diZhi[dp[1]]}';
    print('$y-${m.toString().padLeft(2,"0")}-${d.toString().padLeft(2,"0")}: $gz (期望: ${kd[3]}) ${kd[4]}');
  }

  print('\n=== 用不同偏移量测试 2000-01-01 ===');
  // 2000-01-01 should be 戊午 (gan=4, zhi=6)
  // 戊=idx4, 午=idx6 → 60甲子序号: need 4+60n where n%10=4 and n%12=6 → idx=54
  for (int offset = 0; offset <= 20; offset++) {
    int y = 2000, m = 1, d = 1;
    if (m <= 2) { y -= 1; m += 12; }
    int a2 = y ~/ 100;
    int b2 = 2 - a2 + a2 ~/ 4;
    int jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b2 - 1524;
    int idx = (jd - offset) % 60;
    if (idx < 0) idx += 60;
    String gz = '${tianGan[idx % 10]}${diZhi[idx % 12]}';
    if (gz == '戊午') {
      print('  offset=$offset → $gz ✓ (当前代码用 offset=11)');
    }
  }

  print('\n=== 第3例 23点逻辑分析 ===');
  // 第3例: 1978-01-05 23:00
  // 当前逻辑: hour==23 → adjustedDt = 1978-01-06 → getDayPillar(1978-01-06)
  // 时柱: getHourPillar(23, dayGan of 01-06) → zhiIdx=0(子时)

  var dp_jan5 = getDayPillarOld(DateTime(1978, 1, 5));
  var dp_jan6 = getDayPillarOld(DateTime(1978, 1, 6));
  print('1978-01-05 日柱: ${tianGan[dp_jan5[0]]}${diZhi[dp_jan5[1]]}');
  print('1978-01-06 日柱: ${tianGan[dp_jan6[0]]}${diZhi[dp_jan6[1]]}');

  // Current logic: 23:00 → use dp_jan6 for both day pillar and hour pillar
  var hp_current = getHourPillar(23, dp_jan6[0]);
  print('\n当前代码逻辑 (23点用次日日柱):');
  print('  日柱: ${tianGan[dp_jan6[0]]}${diZhi[dp_jan6[1]]}');
  print('  时柱: ${tianGan[hp_current[0]]}${diZhi[hp_current[1]]}');
  print('  四柱输出: 时${tianGan[hp_current[0]]}${diZhi[hp_current[1]]} 日${tianGan[dp_jan6[0]]}${diZhi[dp_jan6[1]]}');

  // What if we use dp_jan5 (original day) for hour pillar?
  var hp_alt = getHourPillar(23, dp_jan5[0]);
  print('\n如果23点用当日日柱:');
  print('  日柱: ${tianGan[dp_jan5[0]]}${diZhi[dp_jan5[1]]}');
  print('  时柱: ${tianGan[hp_alt[0]]}${diZhi[hp_alt[1]]}');

  print('\n=== 验证: 23点换日后时干是否基于新日柱 ===');
  print('当前代码 calculate() 流程:');
  print('  1. adjustedDt = dt + 1day (因为 hour==23)');
  print('  2. dp = getDayPillar(adjustedDt)  → 用次日日柱 ✓');
  print('  3. hp = getHourPillar(dt.hour=23, dp[0])  → 用次日日干推时干 ✓');
  print('  这个逻辑是自洽的: 23点属于次日子时，日柱和时柱都基于次日');
}
