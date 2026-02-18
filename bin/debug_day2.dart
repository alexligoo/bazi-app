// Cross-verify day pillar with multiple known references
const List<String> tianGan = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const List<String> diZhi = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

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

void main() {
  // Well-documented reference dates from multiple 万年历 sources:
  final refs = {
    '2000-01-01': '戊午',
    '1900-01-01': '甲戌',
    '1949-10-01': '甲子',  // 中华人民共和国成立
    '1976-09-09': '壬午',  // 毛泽东逝世
    '2008-08-08': '戊辰',  // 北京奥运开幕
    '1990-03-15': '己卯',  // 第1例
    '2024-02-10': '甲辰',  // 2024春节 (甲辰年正月初一)
    '1984-01-01': '甲子',  // 甲子年元旦
    '2023-01-22': '癸卯',  // 2023春节 (癸卯年正月初一) - 注意这是日柱不是年柱
  };

  // Actually, let me use the most reliable method:
  // 2000-01-07 is known to be 甲子日 (first 甲子 of 2000)
  // From this we can count forward/backward

  print('=== 日柱公式 vs 已知标准 ===\n');

  // Verified: 2000-01-01 = 戊午 is a well-known reference
  // From 戊午(idx=54 in 60甲子), counting:
  // 2000-01-07 = 54+6=60→0 = 甲子 ✓

  var dp = getDayPillar(DateTime(2000, 1, 7));
  print('2000-01-07: ${tianGan[dp[0]]}${diZhi[dp[1]]} (期望: 甲子)');

  // 1949-10-01: Multiple sources confirm 甲子日
  dp = getDayPillar(DateTime(1949, 10, 1));
  print('1949-10-01: ${tianGan[dp[0]]}${diZhi[dp[1]]} (期望: 甲子)');

  // 2008-08-08: 戊辰日 (Beijing Olympics)
  dp = getDayPillar(DateTime(2008, 8, 8));
  print('2008-08-08: ${tianGan[dp[0]]}${diZhi[dp[1]]} (期望: 戊辰)');

  // Let me verify by counting from 2000-01-01(戊午):
  // 1990-03-15 is 3579 days before 2000-01-01
  int diff = DateTime(2000,1,1).difference(DateTime(1990,3,15)).inDays;
  print('\n2000-01-01 距 1990-03-15: $diff 天');
  // 戊午 = gan4,zhi6. Going back 3579 days:
  // (54 - 3579) % 60 = (54 - 3579 + 60*60) % 60 = (54 - 3579 + 3600) % 60 = 75 % 60 = 15
  // idx 15: gan=15%10=5(己), zhi=15%12=3(卯) → 己卯
  int refIdx = 54; // 戊午 in 60甲子
  int targetIdx = (refIdx - diff) % 60;
  if (targetIdx < 0) targetIdx += 60;
  print('从戊午倒推 $diff 天: idx=$targetIdx → ${tianGan[targetIdx%10]}${diZhi[targetIdx%12]}');

  dp = getDayPillar(DateTime(1990, 3, 15));
  print('公式计算 1990-03-15: ${tianGan[dp[0]]}${diZhi[dp[1]]}');

  // Now verify Example 3: 1978-01-05
  diff = DateTime(2000,1,1).difference(DateTime(1978,1,5)).inDays;
  targetIdx = (refIdx - diff) % 60;
  if (targetIdx < 0) targetIdx += 60;
  print('\n从戊午倒推到 1978-01-05 ($diff天): idx=$targetIdx → ${tianGan[targetIdx%10]}${diZhi[targetIdx%12]}');
  dp = getDayPillar(DateTime(1978, 1, 5));
  print('公式计算 1978-01-05: ${tianGan[dp[0]]}${diZhi[dp[1]]}');

  // 1978-01-06 (23点换日后)
  diff = DateTime(2000,1,1).difference(DateTime(1978,1,6)).inDays;
  targetIdx = (refIdx - diff) % 60;
  if (targetIdx < 0) targetIdx += 60;
  print('从戊午倒推到 1978-01-06 ($diff天): idx=$targetIdx → ${tianGan[targetIdx%10]}${diZhi[targetIdx%12]}');
  dp = getDayPillar(DateTime(1978, 1, 6));
  print('公式计算 1978-01-06: ${tianGan[dp[0]]}${diZhi[dp[1]]}');

  print('\n=== 第3例完整四柱 ===');
  print('1978-01-05 23:00, 男');
  // 23点 → 次日子时 → 日柱用1978-01-06
  dp = getDayPillar(DateTime(1978, 1, 6));
  print('日柱(换日后): ${tianGan[dp[0]]}${diZhi[dp[1]]}');
  // 时柱: 基于次日日干
  int zhiIdx = 0; // 子时
  int startGan = (dp[0] % 5) * 2;
  int hourGan = (startGan + zhiIdx) % 10;
  print('时柱: ${tianGan[hourGan]}${diZhi[zhiIdx]}');
  print('日干${tianGan[dp[0]]}(idx=${dp[0]}) → startGan=${dp[0]%5}*2=$startGan → 时干=(${startGan}+0)%10=$hourGan=${tianGan[hourGan]}');
}
