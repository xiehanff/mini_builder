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
    scheduleMicrotask(_init);
  }

  void _init() {
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
  /// - ids 非空时，仅通知对应 id 的监听器。
  void update([List<String>? ids]) {
    if (_closed) return;

    if (ids == null) {
      super.notifyListeners();
      _notifyAllIdListeners();
      return;
    }

    if (ids.isEmpty) return;

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
