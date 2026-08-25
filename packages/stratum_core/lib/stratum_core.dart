/// Ядро гри STRATUM — тік-рушій, стан симуляції, баланс, офлайн-розрахунок.
///
/// Пакет НЕ залежить від Flutter і не має права на нього посилатись: усе тут
/// має проганятись у `dart test` без емулятора, щоб симуляцію «N тіків за
/// мілісекунди» можна було використовувати як інструмент перевірки балансу.
library;

export 'src/big_double.dart';
export 'src/number_style.dart';
export 'src/tick_engine.dart';
export 'src/tick_scheduler.dart';
