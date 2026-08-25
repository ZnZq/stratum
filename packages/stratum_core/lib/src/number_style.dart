import 'big_double.dart';

/// Контракт нотації: як перетворити велике число на рядок.
///
/// Нотація — поліморфний тип, а не набір прапорців у конфізі. Так зроблено в
/// ADNotations, і причина практична: наступна нотація (літери за межею таблиці,
/// логарифмічна, engineering) стає новим класом, а не третім `switch` у коді.
///
/// Гілкування «нуль / дрібне / велике / від'ємне» описане тут один раз;
/// нащадкам лишається тільки [formatLarge].
abstract class Notation {
  const Notation();

  String format(BigDouble value, NumberStyle style) {
    if (value.isZero) return '0';
    if (value.isNegative) return '-${format(-value, style)}';

    if (value < style.plainBelow) {
      return _trim(value.toDouble().toStringAsFixed(style.placesPlain), style);
    }

    return formatLarge(value, style);
  }

  /// Форматування «великої» частини. Єдине, що визначає конкретну нотацію.
  ///
  /// На вході завжди додатне число, не менше за [NumberStyle.plainBelow].
  String formatLarge(BigDouble value, NumberStyle style);

  static String _trim(String text, NumberStyle style) {
    if (!style.trimTrailingZeros || !text.contains('.')) return text;
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// Мантиса, зведена до діапазону `[1, 1000)` для суфіксної подачі.
  static String formatMantissa(double mantissa, int places, NumberStyle style) =>
      _trim(mantissa.toStringAsFixed(places), style);
}

/// Класична для жанру подача через суфікси: `1.5k`, `12.3m`, `4.2d`.
///
/// За межею таблиці автоматично переходить у [ScientificNotation] — у жанру ця
/// поведінка зветься Mixed Scientific, і межа збігається з тією, на якій
/// перемикається ADNotations.
class SuffixNotation extends Notation {
  const SuffixNotation();

  /// Таблиця суфіксів. Живе тут, тож локалізація — це новий екземпляр нотації,
  /// а не правка коду.
  static const List<String> suffixes = [
    'k', 'm', 'b', 't', 'qa', 'qu', 'sx', 'sp', 'o', 'n', 'd',
  ];

  /// Перша експонента, для якої суфікса вже немає.
  static const int ceilingExponent = 36;

  static const ScientificNotation _fallback = ScientificNotation();

  @override
  String formatLarge(BigDouble value, NumberStyle style) {
    // Кожен суфікс покриває три порядки: k — це 1e3…1e5, m — 1e6…1e8 і далі.
    var exponent = value.exponent;
    var mantissa = value.mantissa * _powersOfTen[exponent % 3];

    // Округлення саме може перекинути число через межу щабля: 999.97 з двома
    // знаками стає 1000.00, і надрукувати це як «1000sx» замість «1sp» було б
    // помилкою. Тому щабель обирається ПІСЛЯ округлення, а не до нього.
    mantissa = double.parse(mantissa.toStringAsFixed(style.places));
    if (mantissa.abs() >= 1000) {
      mantissa /= 1000;
      exponent += 3;
    }

    if (exponent >= ceilingExponent) {
      return _fallback.formatLarge(value, style);
    }

    return Notation.formatMantissa(mantissa, style.places, style) +
        suffixes[exponent ~/ 3 - 1];
  }

  static const List<double> _powersOfTen = [1, 10, 100];
}

/// Показовий запис: `1.5e3`, `2.5e100`.
class ScientificNotation extends Notation {
  const ScientificNotation();

  @override
  String formatLarge(BigDouble value, NumberStyle style) {
    var mantissa = double.parse(value.mantissa.toStringAsFixed(style.places));
    var exponent = value.exponent;

    // Та сама пастка, що й у суфіксів: 9.999 з двома знаками стає 10.00, а
    // «10.00e5» — це не показовий запис.
    if (mantissa.abs() >= 10) {
      mantissa /= 10;
      exponent += 1;
    }

    return '${Notation.formatMantissa(mantissa, style.places, style)}'
        'e${exponent.toStringAsFixed(style.placesExponent)}';
  }
}

/// Як число перетворюється на текст.
///
/// Immutable value object із `const`-конструктором, тож пресети — компіл-тайм
/// константи й чіпляти їх до конкретного числа нічого не коштує.
class NumberStyle {
  const NumberStyle({
    this.notation = const SuffixNotation(),
    this.places = 2,
    this.placesPlain = 1,
    this.placesExponent = 0,
    this.plainBelow = _thousand,
    this.trimTrailingZeros = true,
  });

  /// Яка нотація застосовується до великої частини.
  final Notation notation;

  /// Знаки після коми для чисел, поданих нотацією.
  final int places;

  /// Знаки після коми для чисел, надрукованих як є.
  final int placesPlain;

  /// Знаки після коми в самій експоненті.
  final int placesExponent;

  /// Поріг, під яким число друкується звичайними цифрами без нотації.
  final BigDouble plainBelow;

  /// Чи різати кінцеві нулі: `1.50k` → `1.5k`.
  final bool trimTrailingZeros;

  static const BigDouble _thousand = BigDouble.fromMantissaExponent(1, 3);
  static const BigDouble _quadrillion = BigDouble.fromMantissaExponent(1, 15);

  /// Дефолт гри: суфікси, один знак під тисячею, два — над.
  static const NumberStyle compact = NumberStyle();

  /// Показовий запис на всьому діапазоні над порогом.
  static const NumberStyle scientific = NumberStyle(
    notation: ScientificNotation(),
  );

  /// Цілі величини без суфіксів — глибина в метрах має читатись метрами.
  ///
  /// Поріг звичайного друку піднято до 1e15: глибше за це суфікс усе-таки
  /// зрозуміліший, ніж шістнадцятизначне число.
  static const NumberStyle integer = NumberStyle(
    placesPlain: 0,
    plainBelow: _quadrillion,
  );

  /// Стиль за замовчуванням для всієї гри. Змінюваний у рантаймі — це
  /// налаштування гравця.
  static NumberStyle global = compact;

  String format(BigDouble value) => notation.format(value, this);
}
