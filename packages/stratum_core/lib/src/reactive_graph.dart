typedef Unsubscribe = void Function();

int _batchDepth = 0;
final Set<ReactiveNode<Object?>> _pendingNotifications = {};

/// Runs [body], holding back listener notifications until it finishes.
///
/// Only notifications are held back. Writes land immediately and staleness
/// spreads immediately, so reads inside a batch always see fresh values — which
/// is what a tick loop needs, since it writes and then reads derived values in
/// the same breath.
///
/// Each node notifies its listeners at most once per batch. Nested calls are
/// counted; only the outermost one flushes.
///
/// A throw from [body] does not roll back the writes it already made, so the
/// notifications still go out before the error propagates.
T batch<T>(T Function() body) {
  _batchDepth++;
  try {
    return body();
  } finally {
    _batchDepth--;
    if (_batchDepth == 0) _flushPendingNotifications();
  }
}

void _flushPendingNotifications() {
  if (_pendingNotifications.isEmpty) return;

  final nodes = _pendingNotifications.toList();
  _pendingNotifications.clear();
  for (final node in nodes) {
    node._deliverNotifications();
  }
}

/// A node in a lazily recomputed value graph.
///
/// The graph is pull-based: writing a [Signal] computes nothing, it only marks
/// consumers as possibly stale. Work happens on read, and only the work that
/// cannot be avoided.
///
/// Edges are never declared by hand. While a node computes it sits on the
/// evaluation stack, and any node read during that computation is recorded as a
/// dependency in both directions. Dependency sets may therefore be dynamic: an
/// `if` inside a computation changes them, and that is tracked correctly.
abstract class ReactiveNode<T> {
  ReactiveNode({this.name});

  /// Used in diagnostics. A cycle reported without a name does not say where.
  final String? name;

  /// A `null` on top means an untracked read: no dependency is recorded.
  static final List<ReactiveNode<Object?>?> _evalStack = [];

  /// Counts how many times this node's VALUE actually changed.
  ///
  /// Versions, rather than a bare stale flag, are what lets the cascade stop: a
  /// consumer compares the version it remembers against the current one and, if
  /// they match, computes nothing.
  int _version = 0;

  final Set<ReactiveNode<Object?>> _dependents = {};
  final List<void Function()> _listeners = [];

  /// While set, repeat notifications are pointless: the listener already knows
  /// the value is stale and will re-read once.
  bool _listenersNotified = false;

  bool _disposed = false;

  T get value {
    _assertUsable();
    _settle();
    _registerAsDependencyOfCurrentComputation();
    return _cachedValue;
  }

  /// Detaches the node from the graph for good.
  ///
  /// Dependencies hold their consumers through back edges, so without this a
  /// simulation restart would keep every node of the previous run alive: the
  /// signals that survive a restart (avatar level, capsule tree) would pin them
  /// forever.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pendingNotifications.remove(this);
    _detachFromDependencies();
    _dependents.clear();
    _listeners.clear();
  }

  /// Subscribes to "something upstream changed, worth re-reading".
  ///
  /// This reports invalidation, not a new value: in a pull graph the value is
  /// only known once someone reads it. The listener is expected to read [value].
  ///
  /// Subscribing settles the node first. Without that, a node nobody has read
  /// yet has no edges at all and would never hear about anything.
  Unsubscribe listen(void Function() listener) {
    _assertUsable();
    _settleUntracked();
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _settle();

  T get _cachedValue;

  void _recordDependency(ReactiveNode<Object?> dependency) {}

  /// Removes the back edges through which dependencies hold this node.
  void _detachFromDependencies() {}

  void _markStale();

  void _registerAsDependencyOfCurrentComputation() {
    if (_evalStack.isEmpty) return;
    final consumer = _evalStack.last;
    if (consumer == null || identical(consumer, this)) return;

    consumer._recordDependency(this);
    _dependents.add(consumer);
  }

  void _settleUntracked() {
    _evalStack.add(null);
    try {
      _settle();
    } finally {
      _evalStack.removeLast();
    }
  }

  void _invalidateDependents() {
    for (final dependent in _dependents.toList()) {
      dependent._markStale();
    }
    _notifyListeners();
  }

  void _notifyListeners() {
    if (_listenersNotified || _listeners.isEmpty) return;

    // Set even when delivery is deferred: the listener either already knows or
    // will know at flush, so queueing it twice buys nothing.
    _listenersNotified = true;

    if (_batchDepth > 0) {
      _pendingNotifications.add(this);
      return;
    }
    _deliverNotifications();
  }

  void _deliverNotifications() {
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  void _assertUsable() {
    if (_disposed) {
      throw StateError('node ${name ?? runtimeType} is already disposed');
    }
  }

  @override
  String toString() => '$runtimeType(${name ?? 'unnamed'})';
}

/// A value written from the outside.
class Signal<T> extends ReactiveNode<T> {
  Signal(this._value, {super.name});

  T _value;

  @override
  T get _cachedValue => _value;

  @override
  void _settle() {}

  set value(T newValue) {
    _assertUsable();

    // Writing the same value is not a change. Without this guard every tick
    // would wake the whole graph regardless of whether anything happened.
    if (newValue == _value) return;

    _value = newValue;
    _version++;
    _listenersNotified = false;
    _invalidateDependents();
  }

  @override
  void _markStale() {}
}

/// A value derived from other nodes.
class Computed<T> extends ReactiveNode<T> {
  Computed(this._compute, {super.name});

  final T Function() _compute;

  /// Dependencies together with the versions seen when this node last computed.
  final Map<ReactiveNode<Object?>, int> _dependencies = {};

  late T _value;
  bool _hasValue = false;
  bool _stale = true;
  bool _computing = false;

  @override
  T get _cachedValue => _value;

  @override
  void _recordDependency(ReactiveNode<Object?> dependency) {
    _dependencies[dependency] = dependency._version;
  }

  @override
  void _detachFromDependencies() {
    for (final dependency in _dependencies.keys) {
      dependency._dependents.remove(this);
    }
    _dependencies.clear();
  }

  @override
  void _markStale() {
    // Cascade only on the fresh-to-stale edge. A node already marked stale
    // marked its own consumers back then.
    if (_stale) return;
    _stale = true;
    _listenersNotified = false;
    _invalidateDependents();
  }

  @override
  void _settle() {
    if (_computing) {
      throw StateError(
        'cycle in the value graph: node ${name ?? runtimeType} reads itself, '
        'possibly through a chain of other nodes',
      );
    }
    if (!_stale && _hasValue) return;

    // Stale only means "possibly". Before computing, ask the dependencies
    // whether any of their VALUES actually moved. This is where a cascade from
    // a change that changed nothing dies.
    if (_hasValue && !_anyDependencyChanged()) {
      _stale = false;
      return;
    }

    _recompute();
  }

  bool _anyDependencyChanged() {
    for (final entry in _dependencies.entries) {
      final dependency = entry.key;
      dependency._settle();
      if (dependency._version != entry.value) return true;
    }
    return false;
  }

  void _recompute() {
    // Collected from scratch because the set may have changed if the
    // computation branches. Old back edges have to go, or a dependency that
    // dropped out would keep waking this node.
    _detachFromDependencies();

    _computing = true;
    ReactiveNode._evalStack.add(this);
    final T computed;
    try {
      computed = _compute();
    } finally {
      // Without finally, one throw anywhere in a computation would leave this
      // node on the stack forever and the graph would start recording edges to
      // a node that died long ago.
      ReactiveNode._evalStack.removeLast();
      _computing = false;
    }

    _stale = false;

    // The version moves only when the value really changed. That is what gives
    // consumers the right to compute nothing.
    if (!_hasValue || computed != _value) {
      _value = computed;
      _hasValue = true;
      _version++;
    }
  }
}
