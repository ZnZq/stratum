import '../big_double.dart';

/// The one walk every price ladder shares: levels bought in order until
/// the purse cannot pay the next, with the tolerance every gate must use.
int walkAffordable({
  required BigDouble purse,
  required int level,
  required int cap,
  required int limit,
  required BigDouble Function(int level) price,
}) {
  var left = purse;
  var at = level;
  var count = 0;
  while (at < cap && count < limit) {
    final ask = price(at);
    if (!left.gteWithTolerance(ask)) break;
    left -= ask;
    at++;
    count++;
  }
  return count;
}
