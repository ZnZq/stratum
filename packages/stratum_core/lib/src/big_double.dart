import 'dart:math' as math;

import 'number_style.dart';

/// Число з розширеною експонентою: `mantissa × 10^exponent`.
///
/// Інваріант нормалізації: або число точно нуль (`mantissa == 0 && exponent == 0`),
/// або `1 ≤ |mantissa| < 10`. Інваріант тримає рівність і порівняння тривіальними —
/// без нього `1e3` і `10e2` були б одним числом у двох поданнях.
class BigDouble implements Comparable<BigDouble> {
  /// Створює число з довільної пари мантиси й експоненти, нормалізуючи її.
  factory BigDouble(double mantissa, int exponent) =>
      _normalized(mantissa, exponent);

  /// Створює число з `int` або `double`.
  factory BigDouble.fromNum(num value) => _normalized(value.toDouble(), 0);

  /// Створює число з ВЖЕ нормалізованої пари, без обчислень.
  ///
  /// Потрібен там, де число має бути `const`: нормалізація вимагає логарифма,
  /// а в константному контексті обчислення неможливі. Інваріант тут на совісті
  /// того, хто пише константу, тому його стереже асерт.
  const BigDouble.fromMantissaExponent(this.mantissa, this.exponent)
      : style = null,
        assert(
          mantissa == 0 || (mantissa >= 1 && mantissa < 10) ||
              (mantissa <= -1 && mantissa > -10),
          'мантиса має бути нулем або лежати в [1, 10) за модулем',
        ),
        assert(mantissa != 0 || exponent == 0, 'нуль має канонічну експоненту');

  const BigDouble._raw(this.mantissa, this.exponent, [this.style]);

  /// Значуща частина числа. Нуль, або в межах `[1, 10)` за модулем.
  final double mantissa;

  /// Десяткова експонента.
  final int exponent;

  /// Персональний стиль виводу цього числа.
  ///
  /// Не бере участі ні в рівності, ні в порівнянні, ні в серіалізації — це
  /// подання, а не значення.
  final NumberStyle? style;

  /// Копія з іншим стилем виводу.
  BigDouble withStyle(NumberStyle? style) =>
      BigDouble._raw(mantissa, exponent, style);

  /// Внутрішній шлях, яким операції переносять стиль лівого операнда.
  BigDouble _styled(NumberStyle? style) => identical(style, this.style)
      ? this
      : BigDouble._raw(mantissa, exponent, style);

  /// Найбільша дозволена експонента за модулем.
  ///
  /// Значення взяте з break_infinity.js (`EXP_LIMIT`) заради паритету семантики
  /// з референсними реалізаціями жанру.
  static const int expLimit = 9000000000000000;

  /// Скільки значущих цифр несе мантиса.
  ///
  /// Якщо експоненти двох доданків розходяться більше ніж на це число, менший
  /// не впливає на результат жодним бітом — і додавання має право його
  /// відкинути. Значення взяте з break_infinity.js (`MAX_SIGNIFICANT_DIGITS`).
  static const int maxSignificantDigits = 17;

  /// Дефолтний ВІДНОСНИЙ допуск для порівнянь.
  ///
  /// Значення з break_infinity.js (`ROUND_TOLERANCE`). Ігрові гейти — «чи
  /// вистачає ресурсів», «чи КВ ≥ поріг» — мають користуватись версіями з
  /// допуском, бо два різні шляхи обчислення того самого числа розходяться
  /// в останніх бітах, і строге порівняння тоді бреше гравцеві.
  static const double roundTolerance = 1e-10;

  /// Чи падати на некоректному вході замість того, щоб насичувати значення.
  ///
  /// За замовчуванням увімкнено там, де ввімкнені асерти (debug і тести), і
  /// вимкнено в release. Причина компромісу: у розробці отруєне значення має
  /// впасти в точці виникнення, бо інакше воно тихо розповзеться по стану й
  /// спливе в сейві через годину; у гравця ж сесія важливіша за чистоту, тож
  /// там значення насичується, а факт іде в [onDomainError].
  static bool strictMode = _assertsEnabled();

  /// Куди повідомляти про підміну значення в нестрогому режимі.
  ///
  /// Застосунок може підставити сюди лог або телеметрію. `null` — тиша.
  static void Function(String message)? onDomainError;

  static bool _assertsEnabled() {
    // `assert` вирізається в release, тож побічний ефект спрацює лише в debug.
    // Це єдиний спосіб дізнатись режим, не імпортуючи flutter/foundation.
    var enabled = false;
    assert(enabled = true);
    return enabled;
  }

  /// Спільний шлях для всіх порушень області визначення.
  ///
  /// У строгому режимі кидає, у нестрогому повідомляє й віддає запасне значення.
  static BigDouble _domainError(String message, BigDouble fallback) {
    if (strictMode) throw ArgumentError(message);
    onDomainError?.call(message);
    return fallback;
  }

  static const BigDouble zero = BigDouble._raw(0, 0);
  static const BigDouble one = BigDouble._raw(1, 0);

  /// Найбільше додатне значення, яке тип здатен подати.
  static const BigDouble maxValue = BigDouble._raw(1, expLimit);

  /// Найменше додатне ненульове значення, яке тип здатен подати.
  static const BigDouble minPositive = BigDouble._raw(1, -expLimit);

  bool get isZero => mantissa == 0;

  bool get isNegative => mantissa < 0;

  /// Наближення звичайним `double`. Лоссі за побудовою.
  double toDouble() {
    if (isZero) return 0;
    return mantissa * _pow10(exponent);
  }

  /// −1 для від'ємних, 0 для нуля, 1 для додатних.
  int get sign => mantissa == 0 ? 0 : (mantissa < 0 ? -1 : 1);

  BigDouble operator +(BigDouble other) {
    if (isZero) return other._styled(style);
    if (other.isZero) return this;

    // Якщо експоненти розходяться більше ніж на кількість значущих цифр, менший
    // доданок не може вплинути на жоден біт результату. Це не оптимізація заради
    // швидкості, а тотожність: 1e50 + 1e10 у цій арифметиці ДОРІВНЮЄ 1e50.
    final gap = exponent - other.exponent;
    if (gap > maxSignificantDigits) return this;
    if (gap < -maxSignificantDigits) return other._styled(style);

    // Зводимо обидва доданки до більшої експоненти й додаємо мантиси.
    final bigger = gap >= 0 ? this : other;
    final smaller = gap >= 0 ? other : this;
    final scaled =
        smaller.mantissa / _pow10(bigger.exponent - smaller.exponent);

    return _normalized(bigger.mantissa + scaled, bigger.exponent, style);
  }

  BigDouble operator -(BigDouble other) => this + (-other);

  BigDouble operator *(BigDouble other) {
    if (isZero || other.isZero) return zero._styled(style);
    return _normalized(
      mantissa * other.mantissa,
      _addExponents(exponent, other.exponent),
      style,
    );
  }

  BigDouble operator /(BigDouble other) {
    if (other.isZero) {
      return _domainError(
        'ділення на нуль: $this / $other',
        isZero ? zero : (isNegative ? -maxValue : maxValue),
      );
    }
    if (isZero) return zero._styled(style);
    return _normalized(
      mantissa / other.mantissa,
      _addExponents(exponent, -other.exponent),
      style,
    );
  }

  BigDouble reciprocal() => one / this;

  /// Десятковий логарифм.
  ///
  /// Повертає звичайний `double`, а не [BigDouble], і це безпечно: результат за
  /// модулем не перевищує [expLimit] = 9e15, що лежить під 2^53 ≈ 9.007e15 —
  /// межею точних цілих у `double`. Межу типу було обрано в тому числі заради
  /// цієї властивості.
  double log10() {
    if (sign <= 0) {
      throw ArgumentError.value(this, 'this', 'логарифм визначено лише для додатних');
    }
    return exponent + (math.log(mantissa) / math.ln10);
  }

  /// Натуральний логарифм.
  double ln() => log10() * math.ln10;

  /// Логарифм за довільною основою.
  double log(double base) => log10() / (math.log(base) / math.ln10);

  /// Піднесення до степеня за сталий час незалежно від показника.
  ///
  /// Працює через логарифм: `x^p = 10^(log10(x)·p)`. Саме тому криві на кшталт
  /// `1.055^м` чи `1.13^бури` коштують стільки ж на 10-му метрі, скільки на
  /// десятитисячному.
  BigDouble pow(double power) {
    if (power == 0) return one._styled(style);
    if (isZero) return this;
    if (power == 1) return this;

    if (isNegative) {
      // Від'ємна основа має сенс лише в цілому степені: для дробового результат
      // комплексний, і мовчки повертати NaN тут гірше, ніж впасти.
      if (power != power.roundToDouble()) {
        throw ArgumentError.value(
          power,
          'power',
          'дробовий степінь від\'ємної основи не визначений у дійсних числах',
        );
      }
      final magnitude = abs().pow(power);
      return power.toInt().isEven ? magnitude : -magnitude;
    }

    // Цілий степінь рахуємо множенням, а не логарифмом. Логарифмічний шлях дає
    // 2^3 = 7.999999999999997, і така похибка потім тече в ціни та пороги. У цій
    // грі майже всі степені цілі (1.13^бури, 1.055^метри, 2.5^страти), тож шлях
    // не екзотичний, а основний — і на малих показниках ще й швидший.
    if (power == power.roundToDouble() && power.abs() <= _maxExactIntegerPower) {
      final magnitude = _powBySquaring(power.abs().toInt());
      return (power < 0 ? one / magnitude : magnitude)._styled(style);
    }

    // log10 повертає double, тож добуток може вилетіти за межу типу задовго до
    // того, як щось перетвориться на int — перевіряємо до конвертації, інакше
    // toInt() на нескінченності кине, а на великому значенні обгорнеться.
    final logResult = log10() * power;
    if (!logResult.isFinite || logResult.abs() > expLimit) {
      if (logResult.isNegative) return zero._styled(style);
      return maxValue._styled(style);
    }

    final wholePart = logResult.floorToDouble();
    return _normalized(
        _pow10Fractional(logResult - wholePart), wholePart.toInt(), style);
  }

  /// Стеля для точного шляху піднесення до цілого степеня.
  ///
  /// Бінарне піднесення робить ~log2(n) множень, тож навіть на межі це близько
  /// тридцяти операцій. Вище — логарифмічний шлях: на таких масштабах різниця
  /// в останніх бітах уже не має сенсу.
  static const double _maxExactIntegerPower = 1e9;

  /// Бінарне піднесення до невід'ємного цілого степеня.
  BigDouble _powBySquaring(int power) {
    var result = one;
    var base = this;
    var remaining = power;

    while (remaining > 0) {
      if (remaining.isOdd) result = result * base;
      remaining >>= 1;
      if (remaining > 0) base = base * base;
    }

    return result;
  }

  /// Квадратний корінь.
  BigDouble sqrt() {
    if (isZero) return this;
    if (isNegative) {
      throw ArgumentError.value(this, 'this', 'корінь з від\'ємного не визначений');
    }
    return pow(0.5);
  }

  /// `10^f` для дробового `f` у межах `[0, 1)`.
  static double _pow10Fractional(double f) => math.pow(10.0, f).toDouble();

  // --- Серії покупок -------------------------------------------------------
  //
  // Ціни в грі ростуть геометрично (бур: 15·1.13^n, вузол дерева: 3·1.4^lvl).
  // Питання «скільки я можу купити за наявне» без цих формул перетворюється на
  // цикл, що на пізніх ранах робить тисячі ітерацій на кожне натискання. Тут
  // воно коштує сталий час.

  /// Сумарна ціна [count] наступних покупок при геометричному зростанні.
  static BigDouble sumGeometricSeries(
    BigDouble count,
    BigDouble firstCost,
    BigDouble growth,
    BigDouble owned,
  ) {
    if (count.isZero) return zero;
    final startingPrice = firstCost * growth.pow(owned.toDouble());

    // Ріст рівно вдвічі-втричі — норма, а ріст рівно в одиницю ламає формулу
    // діленням на нуль: там усі покупки коштують однаково.
    if (growth == one) return startingPrice * count;

    return startingPrice *
        (growth.pow(count.toDouble()) - one) /
        (growth - one);
  }

  /// Скільки покупок можна зробити за [resources] при геометричному зростанні.
  static BigDouble affordGeometricSeries(
    BigDouble resources,
    BigDouble firstCost,
    BigDouble growth,
    BigDouble owned,
  ) {
    final startingPrice = firstCost * growth.pow(owned.toDouble());
    if (resources < startingPrice) return zero;
    if (growth == one) return (resources / startingPrice).floor();

    // Обертання формули суми відносно count.
    final ratio = resources / startingPrice * (growth - one) + one;
    return BigDouble.fromNum(ratio.log(growth.toDouble())).floor();
  }

  /// Сумарна ціна [count] наступних покупок при лінійному зростанні.
  static BigDouble sumArithmeticSeries(
    BigDouble count,
    BigDouble firstCost,
    BigDouble step,
    BigDouble owned,
  ) {
    if (count.isZero) return zero;
    final startingPrice = firstCost + owned * step;
    final two = BigDouble.fromNum(2);

    return count * (two * startingPrice + (count - one) * step) / two;
  }

  /// Скільки покупок можна зробити за [resources] при лінійному зростанні.
  static BigDouble affordArithmeticSeries(
    BigDouble resources,
    BigDouble firstCost,
    BigDouble step,
    BigDouble owned,
  ) {
    final startingPrice = firstCost + owned * step;
    if (resources < startingPrice) return zero;
    if (step.isZero) return (resources / startingPrice).floor();

    // Сума лінійного ряду — квадратична за count, тож розв'язуємо квадратне
    // рівняння й беремо додатний корінь.
    final two = BigDouble.fromNum(2);
    final b = startingPrice - step / two;
    final discriminant = b * b + two * step * resources;

    return ((-b + discriminant.sqrt()) / step).floor();
  }

  BigDouble floor() => _rounded((d) => d.floorToDouble());

  BigDouble ceil() => _rounded((d) => d.ceilToDouble());

  BigDouble round() => _rounded((d) => d.roundToDouble());

  BigDouble truncate() => _rounded((d) => d.truncateToDouble());

  /// Спільний шлях для всіх видів округлення.
  ///
  /// За межею значущих цифр дробової частини не існує фізично: у числа з
  /// експонентою ≥ [maxSignificantDigits] мантиса вже не має де тримати дріб,
  /// тож округлювати нічого і значення повертається як є.
  BigDouble _rounded(double Function(double) apply) {
    if (isZero || exponent >= maxSignificantDigits) return this;
    return _normalized(apply(toDouble()), 0, style);
  }

  /// Серіалізація у формат `{mantissa}e{exponent}` — той самий, що приймає
  /// [parse]. Один формат на весь життєвий цикл значення означає, що сейв
  /// можна прочитати очима.
  String toJson() => '${mantissa}e$exponent';

  static BigDouble fromJson(String source) => parse(source);

  /// Розбирає `{mantissa}e{exponent}`, а також звичайне число без експоненти.
  static BigDouble parse(String source) {
    final parsed = tryParse(source);
    if (parsed == null) {
      throw FormatException('не вдалось розібрати як BigDouble', source);
    }
    return parsed;
  }

  static BigDouble? tryParse(String source) {
    final text = source.trim();
    if (text.isEmpty) return null;

    final separator = text.indexOf(RegExp('[eE]'));
    if (separator < 0) {
      final plain = double.tryParse(text);
      return plain == null ? null : _normalized(plain, 0);
    }

    final mantissa = double.tryParse(text.substring(0, separator));
    final exponent = int.tryParse(text.substring(separator + 1));
    if (mantissa == null || exponent == null) return null;

    return _normalized(mantissa, exponent);
  }

  BigDouble abs() =>
      isNegative ? BigDouble._raw(-mantissa, exponent, style) : this;

  BigDouble operator -() =>
      isZero ? this : BigDouble._raw(-mantissa, exponent, style);

  @override
  int compareTo(BigDouble other) {
    // Знак вирішує все: будь-яке від'ємне менше за будь-яке додатне, незалежно
    // від того, наскільки велика його експонента.
    if (sign != other.sign) return sign < other.sign ? -1 : 1;
    if (isZero) return 0;

    // У межах одного знака порядок дає експонента, далі мантиса. Для від'ємних
    // обидва порівняння перевертаються.
    final flip = isNegative ? -1 : 1;
    if (exponent != other.exponent) {
      return exponent < other.exponent ? -flip : flip;
    }
    if (mantissa == other.mantissa) return 0;
    return mantissa < other.mantissa ? -1 : 1;
  }

  bool operator <(BigDouble other) => compareTo(other) < 0;

  bool operator <=(BigDouble other) => compareTo(other) <= 0;

  bool operator >(BigDouble other) => compareTo(other) > 0;

  bool operator >=(BigDouble other) => compareTo(other) >= 0;

  BigDouble min(BigDouble other) => this <= other ? this : other;

  BigDouble max(BigDouble other) => this >= other ? this : other;

  BigDouble clamp(BigDouble lowest, BigDouble highest) {
    if (this < lowest) return lowest;
    if (this > highest) return highest;
    return this;
  }

  /// Порівняння з відносним допуском: `|a − b| ≤ tolerance × max(|a|, |b|)`.
  ///
  /// Відносний, а не абсолютний — щоб те саме рішення ухвалювалось однаково
  /// і на `1e-100`, і на `1e100`.
  bool equalsWithTolerance(BigDouble other, [double tolerance = roundTolerance]) {
    if (isZero && other.isZero) return true;
    if (sign != other.sign) return false;

    final difference = (this - other).abs();
    final scale = abs().max(other.abs());
    return difference <= scale * BigDouble.fromNum(tolerance);
  }

  int compareWithTolerance(BigDouble other, [double tolerance = roundTolerance]) {
    if (equalsWithTolerance(other, tolerance)) return 0;
    return compareTo(other);
  }

  bool gteWithTolerance(BigDouble other, [double tolerance = roundTolerance]) =>
      compareWithTolerance(other, tolerance) >= 0;

  bool lteWithTolerance(BigDouble other, [double tolerance = roundTolerance]) =>
      compareWithTolerance(other, tolerance) <= 0;

  @override
  bool operator ==(Object other) =>
      other is BigDouble &&
      mantissa == other.mantissa &&
      exponent == other.exponent;

  @override
  int get hashCode => Object.hash(mantissa, exponent);

  /// Текстове подання.
  ///
  /// Пріоритет: явний аргумент, далі власний стиль числа, далі
  /// [NumberStyle.global]. Один метод замість двох: інтерполяція йде цим самим
  /// шляхом, тож іншого способу надрукувати число не існує.
  @override
  String toString([NumberStyle? style]) =>
      (style ?? this.style ?? NumberStyle.global).format(this);

  static BigDouble _normalized(double mantissa, int exponent,
      [NumberStyle? style]) {
    if (mantissa.isNaN) {
      return _domainError('NaN не є значенням BigDouble', zero);
    }
    if (mantissa.isInfinite) {
      return _domainError(
        'нескінченність не є значенням BigDouble',
        mantissa.isNegative ? -maxValue : maxValue,
      );
    }
    if (mantissa == 0) return zero._styled(style);

    final shift = (math.log(mantissa.abs()) / math.ln10).floor();
    var m = shift >= 0 ? mantissa / _pow10(shift) : mantissa * _pow10(-shift);
    var e = exponent + shift;

    // Логарифм на межах степеня десятки дає похибку в останньому біті, через яку
    // мантиса може вийти за [1, 10). Поправка одним кроком — інших не буває.
    if (m.abs() >= 10) {
      m /= 10;
      e += 1;
    } else if (m.abs() < 1) {
      m *= 10;
      e -= 1;
    }

    // Насичення на межі типу зберігає знак; провал під нижню межу — це нуль.
    if (e > expLimit) return (m < 0 ? -maxValue : maxValue)._styled(style);
    if (e < -expLimit) return zero._styled(style);

    return BigDouble._raw(m, e, style);
  }

  /// Складає експоненти без затискання — межі типу застосовує [_normalized].
  ///
  /// `int` у Dart при переповненні ОБГОРТАЄТЬСЯ, а не кидає, тож питання
  /// доречне. Але обидва операнди вже лежать у `±expLimit` = ±9e15, отже сума
  /// за модулем не перевищує 1.8e16 — на три порядки менше за межу `int64`.
  /// Затискати тут не можна: інакше провал під нижню межу перетворився б на
  /// «найменше додатне» замість нуля.
  static int _addExponents(int a, int b) => a + b;

  static double _pow10(int n) => math.pow(10.0, n).toDouble();
}

/// Перетворення звичайних чисел без церемоній: `1500.big`.
extension NumToBigDouble on num {
  BigDouble get big => BigDouble.fromNum(this);
}
