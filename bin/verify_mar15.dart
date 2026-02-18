// Triple-verify 1990-03-15 day pillar
const List<String> tianGan = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const List<String> diZhi = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

void main() {
  print('=== 1990-03-15 日柱三重验证 ===\n');

  // Method 1: JD formula (current code)
  int y = 1990, m = 3, d = 15;
  int a2 = y ~/ 100;
  int b2 = 2 - a2 + a2 ~/ 4;
  int jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b2 - 1524;
  int idx = (jd - 11) % 60;
  if (idx < 0) idx += 60;
  print('方法1 (JD公式): JD=$jd, idx=$idx → ${tianGan[idx%10]}${diZhi[idx%12]}');

  // Method 2: Count from J2000.0 epoch
  // 2000-01-01 12:00 UT = JD 2451545.0 = 戊午日 (idx=54)
  // This is THE most well-known astronomical reference point
  int jd2000 = 2451545;
  int idx2000 = (jd2000 - 11) % 60; // Should be 54 = 戊午
  print('\n方法2 (J2000.0基准):');
  print('  J2000.0 (2000-01-01): JD=$jd2000, idx=$idx2000 → ${tianGan[idx2000%10]}${diZhi[idx2000%12]} (应为戊午)');
  int daysDiff = DateTime(2000,1,1).difference(DateTime(1990,3,15)).inDays;
  int targetIdx = (idx2000 - daysDiff) % 60;
  if (targetIdx < 0) targetIdx += 60;
  print('  2000-01-01 到 1990-03-15 差 $daysDiff 天');
  print('  (54 - $daysDiff) % 60 = $targetIdx → ${tianGan[targetIdx%10]}${diZhi[targetIdx%12]}');

  // Method 3: Count from 1949-10-01 = 甲子 (PRC founding, universally documented)
  int daysDiff2 = DateTime(1990,3,15).difference(DateTime(1949,10,1)).inDays;
  int targetIdx2 = daysDiff2 % 60;
  print('\n方法3 (1949-10-01甲子基准):');
  print('  1949-10-01 到 1990-03-15 差 $daysDiff2 天');
  print('  $daysDiff2 % 60 = $targetIdx2 → ${tianGan[targetIdx2%10]}${diZhi[targetIdx2%12]}');

  // Method 4: Count from 2000-01-07 = 甲子 (another well-known甲子日)
  int daysDiff3 = DateTime(2000,1,7).difference(DateTime(1990,3,15)).inDays;
  int targetIdx3 = (60 - (daysDiff3 % 60)) % 60;
  print('\n方法4 (2000-01-07甲子基准):');
  print('  2000-01-07 到 1990-03-15 差 $daysDiff3 天');
  print('  倒推: idx = ${targetIdx3} → ${tianGan[targetIdx3%10]}${diZhi[targetIdx3%12]}');

  // Show what 己巳 would require
  print('\n=== 如果是己巳(idx=5)，需要什么条件？ ===');
  print('己卯 idx=15, 己巳 idx=5, 差10天');
  print('也就是说，如果1990-03-15是己巳，那1990-03-05应该是己卯');

  // Check 1990-03-05
  var dt305 = DateTime(1990, 3, 5);
  int diff305 = dt305.difference(DateTime(1949,10,1)).inDays;
  int idx305 = diff305 % 60;
  print('1990-03-05: 距甲子 $diff305 天, idx=$idx305 → ${tianGan[idx305%10]}${diZhi[idx305%12]}');

  // Check 1990-03-25
  var dt325 = DateTime(1990, 3, 25);
  int diff325 = dt325.difference(DateTime(1949,10,1)).inDays;
  int idx325 = diff325 % 60;
  print('1990-03-25: 距甲子 $diff325 天, idx=$idx325 → ${tianGan[idx325%10]}${diZhi[idx325%12]}');

  // Find which date in March 1990 IS 己巳
  print('\n=== 1990年3月哪天是己巳？ ===');
  for (int day = 1; day <= 31; day++) {
    var dt = DateTime(1990, 3, day);
    int diff = dt.difference(DateTime(1949,10,1)).inDays;
    int i = diff % 60;
    if (i == 5) { // 己巳 = idx 5
      print('1990-03-${day.toString().padLeft(2,"0")} = 己巳');
    }
  }

  // Also show the full sequence around March 15
  print('\n=== 1990年3月13-17日干支 ===');
  for (int day = 13; day <= 17; day++) {
    var dt = DateTime(1990, 3, day);
    int diff = dt.difference(DateTime(1949,10,1)).inDays;
    int i = diff % 60;
    print('3月$day日: ${tianGan[i%10]}${diZhi[i%12]}');
  }
}
