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
  void update([List<String>? ids]) {
    if (_closed) return;

    if (ids == null) {
      super.notifyListeners();
      _notifyAllIdListeners();
      return;
    }

    // 空列表不通知任何监听器
    // 开发时帮助发现潜在的逻辑错误：业务代码通常不应该传空列表
    if (ids.isEmpty) {
      assert(
        false,
        'update([]) called with empty list. '
        'Use update() for full refresh or update([id]) for specific ids.',
      );
      return;
    }

    for (final id in ids) {
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
      if (_idListeners[id]?.contains(fn) ?? false) {
        fn();
      }
    }
  }

  @override
  void dispose() {
    if (_closed) return;

    _closed = true;
    _logLifecycle('onClose');
    onClose();
    _idListeners.clear();
    super.dispose();
  }
}
