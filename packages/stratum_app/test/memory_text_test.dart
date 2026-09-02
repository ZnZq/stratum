import 'package:flutter_test/flutter_test.dart';
import 'package:stratum_app/ui/memory_text.dart';
import 'package:stratum_core/stratum_core.dart';

void main() {
  test('bytes read in binary steps with the digits that fit', () {
    expect(memoryText(BigDouble.fromNum(812)), '812 Б');
    expect(memoryText(BigDouble.fromNum(1536)), '1.50 КБ');
    expect(memoryText(BigDouble.fromNum(38.4 * 1024 * 1024)), '38.4 МБ');
    expect(memoryText(BigDouble.fromNum(1 << 30)), '1.00 ГБ');
    expect(memoryText(BigDouble.fromNum(614.4 * (1 << 30))), '614 ГБ');
  });

  test('past yobibytes the last unit stays and the number carries on', () {
    final huge = BigDouble.fromNum(1024).pow(8) * BigDouble.fromNum(5e7);
    expect(memoryText(huge), endsWith(' ЙБ'));
    expect(memoryText(huge), isNot(startsWith('50000000')));
  });
}
