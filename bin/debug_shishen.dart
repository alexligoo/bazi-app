// Verify ShiShen calculation
const List<String> tianGan = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const List<int> ganWuXing = [0,0,1,1,2,2,3,3,4,4]; // 木火土金水
const List<String> wuXingName = ['木','火','土','金','水'];

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

void main() {
  print('=== 十神标准规则验证 ===');
  print('规则：我生 + 同阴阳 = 食神，我生 + 异阴阳 = 伤官\n');

  // 公认无争议的例子
  print('【公认标准参照】');
  int jia = 0; // 甲(阳木)
  int bing = 2; // 丙(阳火)
  int ding = 3; // 丁(阴火)
  print('甲(阳木)→丙(阳火): 同阳，我生 → ${getShiShen(jia, bing)} (应为食神)');
  print('甲(阳木)→丁(阴火): 异阴阳，我生 → ${getShiShen(jia, ding)} (应为伤官)');

  print('');
  print('【第4例争议点】日主：壬(阳水, idx=8)');
  int ren = 8; // 壬(阳水)
  int yi = 1;  // 乙(阴木)
  print('壬(阳水)→乙(阴木): 水生木，阳→阴(异阴阳) → ${getShiShen(ren, yi)}');
  print('  壬 idx=$ren, 阳阴=${ren % 2 == 0 ? "阳" : "阴"}');
  print('  乙 idx=$yi, 阳阴=${yi % 2 == 0 ? "阳" : "阴"}');
  print('  同阴阳=${(ren % 2) == (yi % 2)} → 异阴阳 → 标准应为伤官');

  print('');
  print('【第6例争议点】日主：己(阴土, idx=5)');
  int ji = 5;  // 己(阴土)
  int xin = 7; // 辛(阴金)
  print('己(阴土)→辛(阴金): 土生金，阴→阴(同阴阳) → ${getShiShen(ji, xin)}');
  print('  己 idx=$ji, 阳阴=${ji % 2 == 0 ? "阳" : "阴"}');
  print('  辛 idx=$xin, 阳阴=${xin % 2 == 0 ? "阳" : "阴"}');
  print('  同阴阳=${(ji % 2) == (xin % 2)} → 同阴阳 → 标准应为食神');

  print('');
  print('【第16例争议点】日主：辛(阴金, idx=7)');
  xin = 7;     // 辛(阴金)
  int gui = 9; // 癸(阴水)
  print('辛(阴金)→癸(阴水): 金生水，阴→阴(同阴阳) → ${getShiShen(xin, gui)}');
  print('  辛 idx=$xin, 阳阴=${xin % 2 == 0 ? "阳" : "阴"}');
  print('  癸 idx=$gui, 阳阴=${gui % 2 == 0 ? "阳" : "阴"}');
  print('  同阴阳=${(xin % 2) == (gui % 2)} → 同阴阳 → 标准应为食神');

  print('');
  print('【完整十神表：甲木日主】');
  for (int i = 0; i < 10; i++) {
    print('  甲→${tianGan[i]}: ${getShiShen(0, i)}');
  }
}
