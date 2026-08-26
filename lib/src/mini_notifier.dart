part of '../mini_builder.dart';

class MiniNotifier extends ChangeNotifier {
  final Map<String, List<VoidCallback>> _idListeners = {};
  bool _initialized = false;
  bool _readyCalled = false;
  bool _closed = false;

  bool get initialized => _initialized;

  bool get readyCalled => _readyCalled;

  bool get closed => _closed;

  MiniNotifier() {
    // 允许 controller 单独创建时也能自动初始化；
    // MiniBuilder 也会再次调用 _ensureInitialized()，但这里靠 _initialized 保证幂等。
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
  /// - ids 为 null 时，通知全部监听器。
  /// - ids 为空时，不通知任何监听器。
  /// - ids 非空时，仅通知对应 id 的监听器；同一次 update 中重复 id 只通知一次。
  void update([List<String>? ids]) {
    if (_closed) return;

    if (ids == null) {
      super.notifyListeners();
      _notifyAllIdListeners();
      return;
    }

    if (ids.isEmpty) return;

    for (final id in ids.toSet()) {
      _notifyIdListeners(id);
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
      super.dispose();
    }
  }
}
