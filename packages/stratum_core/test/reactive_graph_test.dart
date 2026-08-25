import 'package:stratum_core/stratum_core.dart';
import 'package:test/test.dart';

/// A compute counter, the main instrument of these tests.
///
/// Lazy caching is only observable through how many times the compute function
/// actually ran. Without the counter every test would collapse into "the value
/// is right", which proves nothing about wasted work.
class Counted<T> {
  Counted(this.name, this._body);

  final String name;
  final T Function() _body;
  int calls = 0;

  T call() {
    calls++;
    return _body();
  }
}

void main() {
  group('Signal', () {
    test('holds and returns a value', () {
      final s = Signal(10);

      expect(s.value, 10);
    });

    test('takes a new value', () {
      final s = Signal(10)..value = 42;

      expect(s.value, 42);
    });
  });

  group('Computed laziness', () {
    test('does not compute until it is read', () {
      final source = Signal(2);
      final body = Counted('double', () => source.value * 2);
      Computed(body.call);

      expect(body.calls, 0);
    });

    test('computes once no matter how many times it is read', () {
      final source = Signal(2);
      final body = Counted('double', () => source.value * 2);
      final c = Computed(body.call);

      expect(c.value, 4);
      expect(c.value, 4);
      expect(c.value, 4);
      expect(body.calls, 1);
    });

    test('recomputes after a dependency changes', () {
      final source = Signal(2);
      final body = Counted('double', () => source.value * 2);
      final c = Computed(body.call);

      expect(c.value, 4);
      source.value = 5;

      expect(c.value, 10);
      expect(body.calls, 2);
    });

    test('does not recompute twice for one change', () {
      final source = Signal(2);
      final body = Counted('double', () => source.value * 2);
      final c = Computed(body.call);

      c.value;
      source.value = 5;
      c.value;
      c.value;

      expect(body.calls, 2);
    });
  });

  group('writing an equal value changes nothing', () {
    test('a no-op write does not invalidate', () {
      final source = Signal(2);
      final body = Counted('double', () => source.value * 2);
      final c = Computed(body.call);

      c.value;
      source.value = 2;

      expect(c.value, 4);
      expect(body.calls, 1, reason: 'writing the same value is not a change');
    });
  });

  group('the cascade stops where the value stops changing', () {
    test('an unchanged intermediate result does not wake its consumers', () {
      final source = Signal(3);
      // The middle node deliberately loses information: 3 and 4 give the same.
      final middle = Counted('isPositive', () => source.value > 0);
      final middleNode = Computed(middle.call);
      final leaf = Counted('label', () => middleNode.value ? 'yes' : 'no');
      final leafNode = Computed(leaf.call);

      expect(leafNode.value, 'yes');
      expect(middle.calls, 1);
      expect(leaf.calls, 1);

      source.value = 4;

      expect(leafNode.value, 'yes');
      expect(middle.calls, 2, reason: 'the middle node had to recompute');
      expect(leaf.calls, 1,
          reason: 'but the result is the same, so there was nothing to wake the leaf for');
    });

    test('a changed intermediate result does wake them', () {
      final source = Signal(3);
      final middleNode = Computed(() => source.value > 0);
      final leaf = Counted('label', () => middleNode.value ? 'yes' : 'no');
      final leafNode = Computed(leaf.call);

      expect(leafNode.value, 'yes');
      source.value = -1;

      expect(leafNode.value, 'no');
      expect(leaf.calls, 2);
    });
  });

  group('dynamic dependencies', () {
    test('re-collects dependencies on every recompute', () {
      final useLeft = Signal(true);
      final left = Signal(1);
      final right = Signal(100);
      final body = Counted('branch', () => useLeft.value ? left.value : right.value);
      final c = Computed(body.call);

      expect(c.value, 1);
      expect(body.calls, 1);

      // While the branch is left, right is not a dependency and wakes nobody.
      right.value = 200;
      expect(c.value, 1);
      expect(body.calls, 1, reason: 'the right branch is not a dependency');

      useLeft.value = false;
      expect(c.value, 200);
      expect(body.calls, 2);

      // Now the other way around: left has dropped out of the dependencies.
      left.value = 7;
      expect(c.value, 200);
      expect(body.calls, 2, reason: 'the left branch is no longer a dependency');
    });
  });

  group('diamond shape', () {
    test('the merge node computes once per change, not once per path', () {
      // The shape of the STRATUM simulation tree: the Discount node merges the
      // Power and Enrichment branches, both growing from one root.
      final root = Signal(2);
      final power = Computed(() => root.value * 3);
      final enrich = Computed(() => root.value * 5);
      final merge = Counted('discount', () => power.value + enrich.value);
      final mergeNode = Computed(merge.call);

      expect(mergeNode.value, 16);
      expect(merge.calls, 1);

      root.value = 4;

      expect(mergeNode.value, 32);
      expect(merge.calls, 2, reason: 'two paths to the root, but one recomputation');
    });
  });

  group('cycles', () {
    test('a node reading itself is reported, not hung', () {
      late Computed<int> self;
      self = Computed(() => self.value + 1, name: 'self reference');

      expect(() => self.value, throwsA(isA<StateError>()));
    });

    test('a mutual cycle is reported too', () {
      late Computed<int> a;
      late Computed<int> b;
      a = Computed(() => b.value + 1, name: 'a');
      b = Computed(() => a.value + 1, name: 'b');

      expect(() => a.value, throwsA(isA<StateError>()));
    });

    test('the error names the node', () {
      late Computed<int> self;
      self = Computed(() => self.value + 1, name: 'drill power');

      expect(
        () => self.value,
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('drill power')),
        ),
      );
    });
  });

  group('exception safety', () {
    test('a throwing compute does not corrupt the evaluation stack', () {
      final source = Signal(1);
      final boom = Computed<int>(() => throw StateError('on purpose'));

      expect(() => boom.value, throwsStateError);

      // Had the stack stayed corrupted, the next graph would start recording
      // edges to a node that died long ago.
      final healthy = Computed(() => source.value * 2);
      expect(healthy.value, 2);

      source.value = 3;
      expect(healthy.value, 6);
    });

    test('a node that threw can compute successfully later', () {
      final explode = Signal(true);
      final c = Computed<int>(() {
        if (explode.value) throw StateError('not yet');
        return 42;
      });

      expect(() => c.value, throwsStateError);

      explode.value = false;

      expect(c.value, 42);
    });
  });

  group('listeners', () {
    test('fire when something upstream changes', () {
      final source = Signal(1);
      final c = Computed(() => source.value * 2);
      var notifications = 0;

      c.listen(() => notifications++);
      source.value = 2;

      expect(notifications, 1);
    });

    test('fire even when the node was never read', () {
      // Subscribing establishes the dependencies itself; otherwise a node
      // nobody has read has no edges and would never hear about a change.
      final source = Signal(1);
      final c = Computed(() => source.value * 2);
      var notifications = 0;

      c.listen(() => notifications++);
      source.value = 2;

      expect(notifications, 1);
    });

    test('a signal notifies its own listeners', () {
      final source = Signal(1);
      var notifications = 0;

      source.listen(() => notifications++);
      source.value = 2;

      expect(notifications, 1);
    });

    test('an equal write notifies nobody', () {
      final source = Signal(1);
      var notifications = 0;

      source.listen(() => notifications++);
      source.value = 1;

      expect(notifications, 0);
    });

    test('the returned disposer stops them', () {
      final source = Signal(1);
      var notifications = 0;

      final stop = source.listen(() => notifications++);
      source.value = 2;
      stop();
      source.value = 3;

      expect(notifications, 1);
    });

    test('a listener is not spammed while the node is already stale', () {
      final source = Signal(1);
      final c = Computed(() => source.value * 2);
      var notifications = 0;

      c.listen(() => notifications++);
      source.value = 2;
      source.value = 3;
      source.value = 4;

      expect(notifications, 1,
          reason: 'the listener already knows to re-read; repeating buys nothing');

      c.value;
      source.value = 5;

      expect(notifications, 2, reason: 'once it has re-read, notifications make sense again');
    });
  });

  group('carrying game values', () {
    test('drives a STRATUM-shaped power formula', () {
      // power = (10 + 6*drills) * 1.15^tree * (1 + 0.25*modules)
      final drills = Signal(0);
      final treeLevel = Signal(0);
      final modules = Signal(0);

      final base = Computed(() => (10 + 6 * drills.value).big);
      final treeMultiplier = Computed(() => 1.15.big.pow(treeLevel.value.toDouble()));
      final moduleMultiplier = Computed(() => 1.big + 0.25.big * modules.value.big);
      final body = Counted(
        'power',
        () => base.value * treeMultiplier.value * moduleMultiplier.value,
      );
      final power = Computed(body.call);

      expect(power.value, 10.big);
      expect(body.calls, 1);

      drills.value = 5;
      expect(power.value.toDouble(), closeTo(40, 1e-9));

      treeLevel.value = 3;
      expect(power.value.toDouble(), closeTo(40 * 1.520875, 1e-9));
      expect(body.calls, 3);
    });

    test('a display style change never invalidates the balance', () {
      // BigDouble.== ignores the output style, so changing formatting must not
      // touch the computation at all.
      final ore = Signal(1000.big);
      final body = Counted('doubled', () => ore.value * 2.big);
      final doubled = Computed(body.call);

      expect(doubled.value, 2000.big);
      ore.value = 1000.big.withStyle(NumberStyle.scientific);

      expect(doubled.value, 2000.big);
      expect(body.calls, 1);
    });
  });

  group('detaching from the graph', () {
    test('a disposed node stops receiving invalidations', () {
      final source = Signal(1);
      final body = Counted('doubled', () => source.value * 2);
      final c = Computed(body.call);
      var notifications = 0;
      c.listen(() => notifications++);

      expect(c.value, 2);
      c.dispose();
      source.value = 5;

      expect(notifications, 0, reason: 'a disposed node must not hear about changes');
    });

    test('the rest of the graph keeps working after one node leaves', () {
      // The shape of a simulation restart: the run's nodes are discarded while
      // the signals that survive a restart keep feeding the new ones.
      final survivor = Signal(1);
      final oldRun = Computed(() => survivor.value * 2);

      expect(oldRun.value, 2);
      oldRun.dispose();

      final newRun = Computed(() => survivor.value * 10);
      expect(newRun.value, 10);

      survivor.value = 3;
      expect(newRun.value, 30);
    });

    test('reading a disposed node is an error, not a stale answer', () {
      final source = Signal(1);
      final c = Computed(() => source.value * 2);
      c.value;

      c.dispose();

      expect(() => c.value, throwsStateError);
    });

    test('disposing twice is harmless', () {
      final c = Computed(() => 1);
      c.dispose();

      expect(c.dispose, returnsNormally);
    });

    test('a disposed signal stops notifying', () {
      final source = Signal(1);
      var notifications = 0;
      source.listen(() => notifications++);

      source.dispose();

      expect(() => source.value = 2, throwsStateError);
      expect(notifications, 0);
    });
  });
}
