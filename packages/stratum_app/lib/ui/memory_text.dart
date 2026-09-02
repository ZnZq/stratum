import 'package:stratum_core/stratum_core.dart';

/// Bytes as a memory reading: `812 Б`, `1.50 КБ`, `38.4 МБ`, `1.00 ГБ`.
///
/// Binary steps, the way VRAM is quoted, so a one-gibibyte server reads as
/// exactly `1.00 ГБ`. Past yobibytes the figure keeps the last unit and the
/// number style's own suffixes, which is where the game's numbers live.
String memoryText(BigDouble bytes) {
  const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ', 'ПБ', 'ЕБ', 'ЗБ', 'ЙБ'];
  final step = BigDouble.fromNum(1024);
  var value = bytes;
  var unit = 0;
  while (unit < units.length - 1 && value >= step) {
    value = value / step;
    unit++;
  }
  if (unit == 0) return '${value.toDouble().round()} ${units[0]}';
  final d = value.toDouble();
  if (d >= 1e6) return '$value ${units[unit]}';
  final digits = d >= 100
      ? 0
      : d >= 10
      ? 1
      : 2;
  return '${d.toStringAsFixed(digits)} ${units[unit]}';
}
