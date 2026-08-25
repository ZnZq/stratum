import 'dart:async';

import 'tick_scheduler.dart';

/// Джерело монотонного часу.
///
/// Абстракція існує рівно заради одного: щоб тест міг рухати час руками. У
/// продакшені реалізація одна — [StopwatchClock].
abstract class MonotonicClock {
  /// Скільки часу минуло від створення годинника. Ніколи не зменшується.
  Duration get elapsed;
}

/// Реалізація над `Stopwatch`.
///
/// Саме `Stopwatch`, а не `DateTime.now()`: настінний годинник стрибає — NTP
/// підкручує, гравець міняє часовий пояс або свідомо переводить час уперед,
/// щоб накрутити ресурси. Монотонний не стрибає ніколи.
///
/// Настінний час потрібен лише офлайн-розрахунку, бо тільки він переживає
/// вбитий процес — і саме там йому місце, разом із захистом від перекручування
/// годинника. Тік-рушій про `DateTime` не знає.
class StopwatchClock implements MonotonicClock {
  StopwatchClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;
}

/// Драйвер тік-рушія: годує [TickScheduler] реальним часом.
///
/// Логіки тут майже немає — уся вона в крокувальнику, який тестується
/// синхронно. Цей клас відповідає лише за таймер, вимірювання часу й виклик
/// колбека.
class TickEngine {
  TickEngine({
    required this.scheduler,
    required this.onBatch,
    MonotonicClock? clock,
  }) : _clock = clock ?? StopwatchClock() {
    _lastSync = _clock.elapsed;
  }

  final TickScheduler scheduler;

  /// Куди йдуть пачки тіків. Порожні пачки не надсилаються.
  final void Function(TickBatch batch) onBatch;

  final MonotonicClock _clock;

  Timer? _timer;
  late Duration _lastSync;
  bool _disposed = false;

  bool get isRunning => _timer != null;

  TickRate get rate => scheduler.rate;

  /// Змінює ритм і перезаводить таймер під новий інтервал.
  ///
  /// Ходити в `scheduler.rate` повз рушій не можна: період таймера лишився б
  /// старим, і новий ритм проявився б лише через інтервал.
  set rate(TickRate value) {
    scheduler.rate = value;
    _lastSync = _clock.elapsed;
    if (isRunning) {
      _stopTimer();
      _startTimer();
    }
  }

  /// Запускає таймер. Повторний виклик на вже запущеному рушії нічого не робить.
  void start() {
    _assertUsable();
    if (isRunning) return;
    _lastSync = _clock.elapsed;
    _startTimer();
  }

  void stop() => _stopTimer();

  /// Негайно зводить накопичений час, не чекаючи спрацювання таймера.
  ///
  /// Потрібно там, де застосунок сам знає, що час минув — повернення з фону,
  /// відновлення після паузи.
  void syncNow() {
    _assertUsable();

    final now = _clock.elapsed;
    final delta = now - _lastSync;
    _lastSync = now;

    if (delta <= Duration.zero) return;

    final batch = scheduler.advance(delta);
    if (!batch.isEmpty) onBatch(batch);
  }

  void dispose() {
    _stopTimer();
    _disposed = true;
  }

  void _startTimer() {
    _timer = Timer.periodic(scheduler.rate.interval, (_) => syncNow());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _assertUsable() {
    if (_disposed) {
      throw StateError('TickEngine уже звільнено');
    }
  }
}
