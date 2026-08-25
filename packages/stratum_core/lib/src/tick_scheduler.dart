/// Ритм тіків: скільки логічних тіків відбувається за один проміжок часу.
///
/// [ticksPerFire] — це спосіб виразити темп, швидший за інтервал, не вкорочуючи
/// сам інтервал. Рушій жодної нижньої межі на інтервал не має: правило «підлога
/// тіку одна секунда, далі прокачка = дії за тік» — це обмеження конфігу балансу
/// гри, яка просто не подасть сюди менше.
class TickRate {
  TickRate(this.interval, {this.ticksPerFire = 1}) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(
        interval,
        'interval',
        'інтервал тіку має бути додатним',
      );
    }
    if (ticksPerFire < 1) {
      throw ArgumentError.value(
        ticksPerFire,
        'ticksPerFire',
        'за спрацювання має відбуватись хоча б один тік',
      );
    }
  }

  /// Скільки реального часу минає між спрацюваннями.
  final Duration interval;

  /// Скільки логічних тіків дає одне спрацювання.
  final int ticksPerFire;

  @override
  String toString() => '$ticksPerFire тік(ів) / ${interval.inMilliseconds} мс';
}

/// Результат просування часу.
class TickBatch {
  const TickBatch({
    required this.ticks,
    required this.consumed,
    required this.overflow,
  });

  static const TickBatch empty = TickBatch(
    ticks: 0,
    consumed: Duration.zero,
    overflow: Duration.zero,
  );

  /// Скільки логічних тіків треба виконати.
  final int ticks;

  /// Скільки реального часу ці тіки покрили.
  final Duration consumed;

  /// Скільки реального часу викинуто капом наздоганяння.
  ///
  /// Нуль, якщо кап не спрацював. Усе, що тут є, рушій уже не відіграє — цей
  /// час має розібрати офлайн-формула однією формулою від Δt, а не покроковою
  /// симуляцією.
  final Duration overflow;

  bool get isEmpty => ticks == 0;

  @override
  String toString() => 'TickBatch(ticks: $ticks, consumed: $consumed, '
      'overflow: $overflow)';
}

/// Чиста частина тік-рушія: рахує тіки, не знаючи про час і таймери.
///
/// Не має жодного асинхронного методу й жодного джерела часу — час подається
/// ззовні. Саме тому прогін доби гри в тесті займає мілісекунди й не потребує
/// ані емулятора, ані фейкових таймерів.
///
/// Тіки цей клас НЕ виконує: він повертає їхню кількість, а цикл робить
/// викликач. Так гра зможе частину тіків згорнути аналітично замість того,
/// щоб крутити їх по одному.
class TickScheduler {
  TickScheduler({
    required TickRate rate,
    this.maxTicksPerAdvance = defaultMaxTicksPerAdvance,
  }) {
    if (maxTicksPerAdvance < 1) {
      throw ArgumentError.value(
        maxTicksPerAdvance,
        'maxTicksPerAdvance',
        'кап наздоганяння має бути додатним',
      );
    }
    _rate = rate;
  }

  /// Скільки тіків максимум відіграється за одне просування.
  ///
  /// Кап рахує тіки, а не секунди, бо дорога саме кількість виконаних тіків.
  /// Без нього довга пауза породжує борг, який симуляція не може погасити, і
  /// кожен наступний кадр стає гіршим — класичний spiral of death.
  static const int defaultMaxTicksPerAdvance = 64;

  final int maxTicksPerAdvance;

  late TickRate _rate;
  Duration _pending = Duration.zero;

  TickRate get rate => _rate;

  /// Зміна ритму скидає акумулятор.
  ///
  /// Інакше можна було б банкувати час на повільному ритмі й конвертувати його
  /// в пачку тіків, перемкнувшись на швидкий.
  set rate(TickRate value) {
    _rate = value;
    _pending = Duration.zero;
  }

  /// Скільки часу накопичено, але ще не відіграно.
  Duration get pending => _pending;

  void reset() => _pending = Duration.zero;

  /// Просуває час і повідомляє, скільки тіків через це відбулось.
  ///
  /// Інваріант обліку: `pending_до + elapsed == consumed + overflow + pending_після`.
  /// Жодна мілісекунда не зникає й не з'являється.
  TickBatch advance(Duration elapsed) {
    if (elapsed < Duration.zero) {
      throw ArgumentError.value(
        elapsed,
        'elapsed',
        'час не йде назад: рушій міряє монотонним годинником',
      );
    }

    _pending += elapsed;

    final possibleFires = _pending.inMicroseconds ~/ _rate.interval.inMicroseconds;
    if (possibleFires == 0) return TickBatch.empty;

    final maxFires = maxTicksPerAdvance ~/ _rate.ticksPerFire;
    final fires = possibleFires < maxFires ? possibleFires : maxFires;

    final consumed = _rate.interval * fires;
    _pending -= consumed;

    // Кап спрацював лише якщо ми справді не догнали. Тоді решта накопиченого
    // йде назовні: тримати її всередині означало б відкласти той самий борг.
    var overflow = Duration.zero;
    if (fires < possibleFires) {
      overflow = _pending;
      _pending = Duration.zero;
    }

    return TickBatch(
      ticks: fires * _rate.ticksPerFire,
      consumed: consumed,
      overflow: overflow,
    );
  }
}
