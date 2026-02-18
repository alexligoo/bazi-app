
import 'package:flutter_test/flutter_test.dart';
import 'package:bazi_app/main.dart';

void main() {
  test('Reproduce BaZi Calculation', () {
    const input = "1995年正月二十九辰时 女命";
    print("Input: $input");

    final parsed = parseInput(input);
    print("Parsed Result: $parsed");

    if (parsed['year'] != null && parsed['month'] != null && parsed['day'] != null) {
      // Create DateTime. If parsing returned Solar (which parseInput does for Lunar input if conversion successful), 
      // then this is the Solar Date.
      DateTime dt = DateTime(parsed['year']!, parsed['month']!, parsed['day']!, parsed['hour'] ?? 12);
      
      print("Calculated Date (Should be Solar): $dt");
      
      // Check Lunar to Solar conversion manually if possible
      // 1995 Lunar 1.29 -> Solar 1995.2.28
      
      final result = calculate(dt, parsed['isMale'] ?? true, name: parsed['name'] ?? '');
      
      print("=== BaZi Chart ===");
      print("Year: ${result.yearGanStr}${result.yearZhiStr}");
      print("Month: ${result.monthGanStr}${result.monthZhiStr}");
      print("Day: ${result.dayGanStr}${result.dayZhiStr}");
      print("Hour: ${result.hourGanStr}${result.hourZhiStr}");
      print("Start Age (Qi Yun): ${result.startAge}");
      
      // Check Li Chun for 1995
      final lichun = getLiChun(1995);
      print("Li Chun 1995: $lichun");
      
      // Check next Jie Qi (Jing Zhe)
      final jingzhe = getSolarTerm(1995, 2 * 1 + 2); // n=4?
      // getSolarTerm(year, n). n=1 is Yu Shui? 
      // Month 1 (Tiger): Li Chun (n=2, approx Feb 4) -> Jing Zhe (n=4, approx Mar 6)
      // Code: getSolarTerm(1995, 2) is Li Chun.
      // 2 * month = 2 * 1 = 2 -> Li Chun.
      // Next is 2 * 2 = 4 -> Jing Zhe.
      final jingzhe2 = getSolarTerm(1995, 4);
      print("Jing Zhe 1995: $jingzhe2");
      
    } else {
      print("Failed to parse date.");
    }
  });
}
