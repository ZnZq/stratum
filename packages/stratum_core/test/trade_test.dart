import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

void main() {
  const minute = 60 * 1000;

  PrototypeSimulation stocked() {
    final sim = PrototypeSimulation();
    sim.stock.add(ResourceId.regolith, BigDouble.fromNum(1000));
    sim.stock.add(ResourceId.cuprite, BigDouble.fromNum(100));
    return sim;
  }

  group('selling', () {
    test('a manual sale moves the share and pays list price', () {
      final sim = stocked();
      sim.sellShareOf(ResourceId.regolith).value = 25;
      final paid = sim.sellPosition(ResourceId.regolith);
      expect(paid.toDouble(), closeTo(250 * 0.4, 1e-9));
      expect(sim.stock.amount(ResourceId.regolith).toDouble(),
          closeTo(750, 1e-9));
      expect(sim.stock.amount(ResourceId.credits).toDouble(),
          closeTo(100, 1e-9));
    });

    test('sell-all skips a switched-off position', () {
      final sim = stocked();
      sim.sellingOf(ResourceId.cuprite).value = false;
      final quoted = sim.sellAllYield();
      final paid = sim.sellAll();
      expect(paid.toDouble(), closeTo(quoted.toDouble(), 1e-6));
      expect(paid.toDouble(), closeTo(1000 * 0.4, 1e-9));
      expect(sim.stock.amount(ResourceId.cuprite).toDouble(),
          closeTo(100, 1e-9));
    });

    test('the toggle does not disarm the manual button', () {
      final sim = stocked();
      sim.sellingOf(ResourceId.cuprite).value = false;
      final paid = sim.sellPosition(ResourceId.cuprite);
      expect(paid.toDouble(), closeTo(100 * 820, 1e-6));
    });
  });

  group('requests', () {
    test('the first sync posts a request immediately', () {
      final sim = stocked();
      sim.syncRequests(minute);
      expect(sim.requests, hasLength(1));
      expect(sim.nextRequestAtMs, greaterThan(minute));
    });

    test('a request expires without penalty', () {
      final sim = stocked();
      sim.syncRequests(minute);
      final before = sim.stock.amount(ResourceId.credits);
      sim.syncRequests(
        minute + PrototypeSimulation.requestLifetimeMs + minute * 30,
      );
      expect(sim.stock.amount(ResourceId.credits).toDouble(),
          before.toDouble());
      // The board refills on the same sync: expiry is not a drought.
      expect(sim.requests, isNotEmpty);
    });

    test('a long absence posts at most a boardful', () {
      final sim = stocked();
      sim.syncRequests(minute);
      sim.syncRequests(minute + 500 * minute);
      expect(sim.requests.length, lessThanOrEqualTo(sim.requestSlots));
    });

    test('fulfilling pays list price plus the premium and spends the needs',
        () {
      final sim = stocked();
      sim.syncRequests(minute);
      final request = sim.requests.single;
      final payout = sim.requestPayout(request);
      var list = BigDouble.zero;
      for (final need in request.needs) {
        list += need.amount * sim.sellPrice(need.id);
      }
      expect(payout.toDouble(),
          closeTo(list.toDouble() * (1 + request.premium), 1e-6));
      expect(sim.canFulfil(request), isTrue);
      final held = {
        for (final need in request.needs)
          need.id: sim.stock.amount(need.id),
      };
      expect(sim.fulfilRequest(request), isTrue);
      expect(sim.requests, isEmpty);
      expect(sim.stock.amount(ResourceId.credits).toDouble(),
          closeTo(payout.toDouble(), 1e-6));
      for (final need in request.needs) {
        expect(sim.stock.amount(need.id).toDouble(),
            closeTo((held[need.id]! - need.amount).toDouble(), 1e-6));
      }
    });

    test('a request never asks for what the run has not seen', () {
      final sim = PrototypeSimulation();
      // A fresh run holds nothing sellable: no request can be written.
      sim.syncRequests(minute);
      expect(sim.requests, isEmpty);
      sim.stock.add(ResourceId.regolith, BigDouble.fromNum(50));
      sim.syncRequests(minute + PrototypeSimulation.requestIntervalMs + 1);
      expect(sim.requests, isNotEmpty);
      for (final request in sim.requests) {
        for (final need in request.needs) {
          expect(need.id, ResourceId.regolith);
        }
      }
    });
  });

  test('trade settings and the board survive a save', () {
    final sim = stocked();
    sim.sellingOf(ResourceId.regolith).value = false;
    sim.sellShareOf(ResourceId.cuprite).value = 50;
    sim.syncRequests(minute);
    final json = sim.toJson();

    final back = PrototypeSimulation()..readJson(json);
    expect(back.sellingOf(ResourceId.regolith).value, isFalse);
    expect(back.sellShareOf(ResourceId.cuprite).value, 50);
    expect(back.sellingOf(ResourceId.cuprite).value, isTrue);
    expect(back.nextRequestAtMs, sim.nextRequestAtMs);
    expect(back.requests, hasLength(sim.requests.length));
    expect(back.requestPayout(back.requests.first).toDouble(),
        closeTo(sim.requestPayout(sim.requests.first).toDouble(), 1e-6));
  });
}
