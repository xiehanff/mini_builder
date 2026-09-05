part of '../mini_builder.dart';

class MiniNotifier extends ChangeNotifier {
  final Map<String, List<VoidCallback>> _idListeners = {};
  final List<void Function(MiniChange change)> _changeListeners =
      <void Function(MiniChange change)>[];
  final Set<MiniWorker> _workers = <MiniWorker>{};
  bool _initialized = false;
  bool _readyCalled = false;
  bool _closed = false;

  bool get initialized => _initialized;

  bool get readyCalled => _readyCalled;

  bool get closed => _closed;

  MiniNotifier() {
    // 在 microtask 中调用 onInit，确保：
    // 1. 构造函数体和初始化列表完全执行完毕
    // 2. 子类构造函数中的字段赋值已完成
    //
    // 注意：不要在构造函数体中访问依赖 onInit 的字段，它们此时尚未初始化。
    // MiniBuilder 也会调用 _ensureInitialized()，但 _initialized 标志保证幂等性。
    scheduleMicrotask(_ensureInitialized);
  }

  void _ensureInitialized() {
    if (_closed || _initialized) return;

    _initialized = true;
    _logLifecycle('onInit');
    onInit();
  }

  void _ready() {
    if (_closed || !_initialized || _readyCalled) return;

    _readyCalled = true;
    _logLifecycle('onReady');
    onReady();
  }

  @protected
  @mustCallSuper
  void onInit() {}

  @protected
  @mustCallSuper
  void onReady() {}

  @protected
  @mustCallSuper
  void onClose() {}

  void _logLifecycle(String name) {
    if (kReleaseMode) return;

    debugPrint('[mini_builder] $runtimeType.$name');
  }

  void addIdListener(String id, VoidCallback listener) {
    if (_closed) return;

    _idListeners.putIfAbsent(id, () => <VoidCallback>[]).add(listener);
  }

  void removeIdListener(String id, VoidCallback listener) {
    final listeners = _idListeners[id];
    if (listeners == null) return;

    listeners.remove(listener);
    if (listeners.isEmpty) {
      _idListeners.remove(id);
    }
  }

  /// 通知监听器，支持按 id 细粒度刷新。
  ///
  /// 调用方式：
  /// - `update()` 或 `update(null)` - 全量刷新：通知全部普通监听器和所有 id 监听器
  /// - `update([])` - 空列表不通知任何监听器（开发模式会触发断言提示）
  /// - `update(['id1', 'id2'])` - 局部刷新：只通知指定 id 的监听器，不通知普通监听器
  ///
  void update([List<String>? ids]) {
    if (_closed) return;

    final changedIds = ids?.toSet();

    // 空列表不通知任何监听器
    // 开发时帮助发现潜在的逻辑错误：业务代码通常不应该传空列表
    if (changedIds != null && changedIds.isEmpty) {
      assert(
        false,
        'update([]) called with empty list. '
        'Use update() for full refresh or update([id]) for specific ids.',
      );
      return;
    }

    Mini._schedule(this, changedIds);
  }

  void _dispatchUpdate(Set<String>? ids) {
    if (_closed) return;

    if (ids == null) {
      super.notifyListeners();
      _notifyAllIdListeners();
    } else {
      for (final id in ids) {
        _notifyIdListeners(id);
      }
    }

    _notifyChangeListeners(MiniChange._(this, ids));
  }

  /// 订阅此 controller 发出的所有更新。
  ///
  /// 用于 controller 间依赖。Widget 应使用 [MiniBuilder]。
  void addChangeListener(void Function(MiniChange change) listener) {
    if (_closed) return;
    _changeListeners.add(listener);
  }

  void removeChangeListener(void Function(MiniChange change) listener) {
    _changeListeners.remove(listener);
  }

  /// 监听 [source] 并随此 controller 自动销毁订阅。
  MiniWorker watch(
    MiniNotifier source, {
    Iterable<String>? ids,
    bool fireImmediately = false,
    required void Function(MiniChange change) onChanged,
  }) {
    if (_closed || source.closed) return _disposedWorker();

    final observedIds = ids == null ? null : Set<String>.of(ids);
    return _watch(
      source,
      observedIds: observedIds,
      fireImmediately: fireImmediately,
      onChanged: onChanged,
    );
  }

  /// 将多个数据源作为一个依赖监听。当 [coalesce] 为 true 时，
  /// 同一同步调用栈中的多个源变更会在一个 microtask 中合并为一次 [onChanged] 调用。
  MiniWorker watchAll(
    Iterable<MiniWatchSource> sources, {
    bool fireImmediately = false,
    bool coalesce = true,
    required void Function(List<MiniChange> changes) onChanged,
  }) {
    if (_closed) return _disposedWorker();

    final liveSources =
        sources.where((source) => !source.controller.closed).toList();
    if (liveSources.isEmpty) return _disposedWorker();

    final dependencies = <_MiniDependency>[];
    try {
      for (final source in liveSources) {
        dependencies.add(
          Mini._registerDependency(source: source.controller, owner: this),
        );
      }
    } catch (_) {
      for (final dependency in dependencies) {
        Mini._unregisterDependency(dependency);
      }
      rethrow;
    }

    final changes = <MiniChange>[];
    var scheduled = false;
    var disposed = false;
    final listeners = <MiniWatchSource, void Function(MiniChange change)>{};

    void flush() {
      scheduled = false;
      if (disposed || changes.isEmpty) return;

      final nextChanges = List<MiniChange>.of(changes);
      changes.clear();
      _invokeWorker(
        () => onChanged(nextChanges),
        'while dispatching a coalesced MiniNotifier dependency',
      );
    }

    void handle(MiniChange change) {
      if (disposed) return;
      if (!coalesce) {
        _invokeWorker(
          () => onChanged(<MiniChange>[change]),
          'while dispatching a MiniNotifier dependency',
        );
        return;
      }

      changes.add(change);
      if (scheduled) return;

      scheduled = true;
      scheduleMicrotask(flush);
    }

    for (final source in liveSources) {
      void listener(MiniChange change) {
        if (change.matches(source.ids)) {
          handle(change);
        }
      }

      listeners[source] = listener;
      source.controller.addChangeListener(listener);
    }

    late final MiniWorker worker;
    worker = MiniWorker._(() {
      disposed = true;
      for (final entry in listeners.entries) {
        entry.key.controller.removeChangeListener(entry.value);
      }
      for (final dependency in dependencies) {
        Mini._unregisterDependency(dependency);
      }
      _workers.remove(worker);
    });
    _workers.add(worker);

    if (fireImmediately) {
      _invokeWorker(
        () => onChanged(const <MiniChange>[]),
        'while immediately dispatching a MiniNotifier dependency',
      );
    }
    return worker;
  }

  /// 在更新停止 [duration] 后监听 [source]（防抖）。
  MiniWorker debounce(
    MiniNotifier source, {
    Iterable<String>? ids,
    required Duration duration,
    bool fireImmediately = false,
    required void Function(MiniChange change) onChanged,
  }) {
    if (_closed || source.closed) return _disposedWorker();

    Timer? timer;
    MiniChange? lastChange;
    late final MiniWorker worker;
    worker = _watch(
      source,
      observedIds: ids == null ? null : Set<String>.of(ids),
      fireImmediately: false,
      onChanged: (change) {
        lastChange = change;
        timer?.cancel();
        timer = Timer(duration, () {
          final nextChange = lastChange;
          if (!worker.disposed && nextChange != null) {
            _invokeWorker(
              () => onChanged(nextChange),
              'while dispatching a debounced MiniNotifier dependency',
            );
          }
        });
      },
      additionalDispose: () => timer?.cancel(),
    );

    if (fireImmediately) {
      _invokeWorker(
        () => onChanged(MiniChange._(source, null)),
        'while immediately dispatching a debounced MiniNotifier dependency',
      );
    }
    return worker;
  }

  /// 在每个 [duration] 内最多监听 [source] 一次（节流）。
  MiniWorker interval(
    MiniNotifier source, {
    Iterable<String>? ids,
    required Duration duration,
    bool fireImmediately = false,
    required void Function(MiniChange change) onChanged,
  }) {
    if (_closed || source.closed) return _disposedWorker();

    var available = true;
    Timer? timer;
    late final MiniWorker worker;
    worker = _watch(
      source,
      observedIds: ids == null ? null : Set<String>.of(ids),
      fireImmediately: false,
      onChanged: (change) {
        if (!available) return;

        available = false;
        timer = Timer(duration, () {
          available = true;
        });
        _invokeWorker(
          () => onChanged(change),
          'while dispatching an interval MiniNotifier dependency',
        );
      },
      additionalDispose: () => timer?.cancel(),
    );

    if (fireImmediately) {
      _invokeWorker(
        () => onChanged(MiniChange._(source, null)),
        'while immediately dispatching an interval MiniNotifier dependency',
      );
    }
    return worker;
  }

  MiniWorker _watch(
    MiniNotifier source, {
    required Set<String>? observedIds,
    required bool fireImmediately,
    required void Function(MiniChange change) onChanged,
    VoidCallback? additionalDispose,
  }) {
    if (_closed || source.closed) return _disposedWorker();

    final dependency = Mini._registerDependency(source: source, owner: this);
    late final void Function(MiniChange change) listener;
    late final MiniWorker worker;
    listener = (change) {
      if (change.matches(observedIds)) {
        _invokeWorker(
          () => onChanged(change),
          'while dispatching a MiniNotifier dependency',
        );
      }
    };
    source.addChangeListener(listener);

    worker = MiniWorker._(() {
      additionalDispose?.call();
      source.removeChangeListener(listener);
      Mini._unregisterDependency(dependency);
      _workers.remove(worker);
    });
    _workers.add(worker);

    if (fireImmediately) {
      _invokeWorker(
        () => onChanged(MiniChange._(source, null)),
        'while immediately dispatching a MiniNotifier dependency',
      );
    }
    return worker;
  }

  MiniWorker _disposedWorker() {
    final worker = MiniWorker._(() {});
    worker.dispose();
    return worker;
  }

  void _invokeWorker(VoidCallback callback, String context) {
    try {
      callback();
    } catch (exception, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'mini_builder',
          context: ErrorDescription(context),
          informationCollector: () => <DiagnosticsNode>[
            DiagnosticsProperty<MiniNotifier>('controller', this),
          ],
        ),
      );
    }
  }

  void _notifyChangeListeners(MiniChange change) {
    for (final listener in List<void Function(MiniChange change)>.of(
      _changeListeners,
    )) {
      if (!_changeListeners.contains(listener)) continue;

      try {
        listener(change);
      } catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'mini_builder',
            context: ErrorDescription(
              'while dispatching a MiniNotifier controller dependency',
            ),
            informationCollector: () => <DiagnosticsNode>[
              DiagnosticsProperty<MiniNotifier>('controller', this),
            ],
          ),
        );
      }
    }
  }

  void _notifyAllIdListeners() {
    for (final id in List<String>.of(_idListeners.keys)) {
      _notifyIdListeners(id);
    }
  }

  void _notifyIdListeners(String id) {
    final listeners = _idListeners[id];
    if (listeners == null || listeners.isEmpty) return;

    for (final fn in List<VoidCallback>.of(listeners)) {
      // 先拷贝快照避免遍历时修改列表，再跳过本轮已经移除的 listener。
      if (!(_idListeners[id]?.contains(fn) ?? false)) continue;

      try {
        fn();
      } catch (exception, stack) {
        // 与 ChangeNotifier.notifyListeners() 保持一致：单个监听器异常
        // 不应阻断同一轮中的其他监听器。
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'mini_builder',
            context: ErrorDescription(
              'while dispatching an update for MiniNotifier id "$id"',
            ),
            informationCollector: () => <DiagnosticsNode>[
              DiagnosticsProperty<MiniNotifier>('controller', this),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_closed) return;

    _closed = true;
    _logLifecycle('onClose');

    try {
      onClose();
    } finally {
      // 即使业务 onClose 抛异常，也必须完成框架自身的清理，避免 controller
      // 停留在 closed=true 但 ChangeNotifier 尚未 dispose 的半销毁状态。
      _idListeners.clear();
      for (final worker in List<MiniWorker>.of(_workers)) {
        worker.dispose();
      }
      _changeListeners.clear();
      super.dispose();
    }
  }
}
