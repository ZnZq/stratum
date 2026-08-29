import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  PrototypeSimulation stocked() {
    final sim = PrototypeSimulation();
    sim.stock.add(ResourceId.regolith, BigDouble.fromNum(100000));
    return sim;
  }

  test('sales raise the turnover and the turnover closes rounds', () {
    final sim = stocked();
    expect(sim.financeRound, 0);
    final paid = sim.sellPosition(ResourceId.regolith);
    expect(sim.creditsEarned.value.toDouble(),
        closeTo(paid.toDouble(), 1e-6));
    // 100k regolith at 0.4 = 40k credits: several rounds on the ladder.
    expect(sim.financeRound, greaterThan(0));
    expect(sim.tranchesFree, sim.financeRound);
  });

  test('the ladder is geometric and the log inversion agrees with it', () {
    final sim = PrototypeSimulation();
    for (var round = 1; round < 12; round++) {
      // Just past the floor of a round is exactly that round.
      sim.creditsEarned.value =
          sim.roundFloor(round) + BigDouble.fromNum(0.001);
      expect(sim.financeRound, round, reason: 'round $round');
      // Just short of it is the round before.
      sim.creditsEarned.value =
          sim.roundFloor(round) - BigDouble.fromNum(0.001);
      expect(sim.financeRound, round - 1, reason: 'below round $round');
    }
  });

  test('spending is gated by free tranches', () {
    final sim = PrototypeSimulation();
    expect(sim.investTranche(FundLine.sales), isFalse);
    sim.creditsEarned.value = sim.roundFloor(2) + BigDouble.one;
    expect(sim.investTranche(FundLine.sales), isTrue);
    expect(sim.investTranche(FundLine.extraction), isTrue);
    expect(sim.investTranche(FundLine.telemetry), isFalse);
    expect(sim.tranchesFree, 0);
  });

  test('the sales line multiplies quotes, payouts and the request board',
      () {
    final sim = stocked();
    final before = sim.sellYield(ResourceId.regolith);
    sim.creditsEarned.value = sim.roundFloor(1) + BigDouble.one;
    sim.investTranche(FundLine.sales);
    final after = sim.sellYield(ResourceId.regolith);
    expect(after.toDouble() / before.toDouble(), closeTo(1.05, 1e-9));
    // And the button pays exactly what it quoted.
    final quoted = sim.sellYield(ResourceId.regolith);
    final paid = sim.sellPosition(ResourceId.regolith);
    expect(paid.toDouble(), closeTo(quoted.toDouble(), 1e-6));
  });

  test('extraction and telemetry raise their own forecasts and not the '
      'other lane', () {
    final sim = PrototypeSimulation();
    final ore = sim.expectedPerStrike(ResourceId.regolith);
    final data = sim.expectedPerStrike(ResourceId.rawData);
    sim.creditsEarned.value = sim.roundFloor(1) + BigDouble.one;
    sim.investTranche(FundLine.extraction);
    expect(
      sim.expectedPerStrike(ResourceId.regolith).toDouble() / ore.toDouble(),
      closeTo(1.05, 1e-9),
    );
    expect(sim.expectedPerStrike(ResourceId.rawData).toDouble(),
        closeTo(data.toDouble(), 1e-9));
  });

  test('financing survives a save', () {
    final sim = stocked();
    sim.sellPosition(ResourceId.regolith);
    sim.investTranche(FundLine.telemetry);
    final back = PrototypeSimulation()..readJson(sim.toJson());
    expect(back.creditsEarned.value.toDouble(),
        closeTo(sim.creditsEarned.value.toDouble(), 1e-6));
    expect(back.fundingOf(FundLine.telemetry).value, 1);
    expect(back.tranchesFree, sim.tranchesFree);
  });
}
