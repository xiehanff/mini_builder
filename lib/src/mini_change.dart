part of '../mini_builder.dart';

/// [MiniNotifier] 发出的变更事件。
///
/// [ids] 为 `null` 表示全量 `update()`，非空则包含局部更新传入的 id 集合。
class MiniChange {
  MiniChange._(this.source, Set<String>? ids)
      : ids = ids == null ? null : Set<String>.unmodifiable(ids);

  final MiniNotifier source;
  final Set<String>? ids;

  bool get isFullRefresh => ids == null;

  /// 判断此变更是否应该通知正在观察 [observedIds] 的 worker。
  ///
  /// 匹配逻辑：
  /// - `observedIds == null`：worker 观察所有变更 → 始终匹配
  /// - `this.ids == null`：全量更新 → 匹配所有 worker（controller 未声明具体变更字段）
  /// - 否则：变更 id 集合中任一 id 出现在观察集合中即匹配
  ///
  /// 示例：
  /// ```dart
  /// final change = MiniChange._(controller, {'fieldA', 'fieldB'});
  ///
  /// change.matches(null);              // true（观察全部）
  /// change.matches({'fieldA'});        // true（fieldA 已变更）
  /// change.matches({'fieldC'});        // false（fieldC 未变更）
  /// change.matches({'fieldA', 'fieldC'}); // true（fieldA 在两个集合中）
  ///
  /// final fullChange = MiniChange._(controller, null);
  /// fullChange.matches({'fieldA'});    // true（全量更新匹配所有）
  /// ```
  bool matches(Set<String>? observedIds) {
    if (observedIds == null || ids == null) return true;
    return ids!.any(observedIds.contains);
  }
}

/// 取消由 [MiniNotifier.watch] 及相关 API 创建的订阅。
///
/// Controller 创建的 worker 会随 controller 自动销毁。
/// 提前调用 [dispose] 是安全且幂等的。
class MiniWorker {
  MiniWorker._(this._onDispose);

  VoidCallback? _onDispose;

  bool get disposed => _onDispose == null;

  void dispose() {
    final onDispose = _onDispose;
    if (onDispose == null) return;

    _onDispose = null;
    onDispose();
  }
}

/// [MiniNotifier.watchAll] 使用的数据源。
class MiniWatchSource {
  MiniWatchSource(this.controller, {Iterable<String>? ids})
      : ids = ids == null ? null : Set<String>.unmodifiable(ids);

  final MiniNotifier controller;
  final Set<String>? ids;
}

/// 将 controller 更新分组，每个 controller 合并为一次派发。
///
/// 当一个业务操作修改多个全局 controller 时很有用。
/// UI 监听器和 controller worker 在最外层 batch 完成后收到合并的更新。
abstract final class Mini {
  static const int _maxDispatchDepth = 100;
  static const int _maxFlushIterations = 100;
  static int _batchDepth = 0;
  static final Map<MiniNotifier, _PendingChange> _pendingChanges =
      HashMap<MiniNotifier, _PendingChange>.identity();
  static final Map<MiniNotifier, Map<MiniNotifier, int>> _dependencies =
      HashMap<MiniNotifier, Map<MiniNotifier, int>>.identity();
  static final List<MiniNotifier> _dispatchStack = <MiniNotifier>[];

  static void batch(VoidCallback action) {
    _batchDepth++;
    try {
      action();
    } finally {
      _batchDepth--;
      if (_batchDepth == 0) {
        _flush();
      }
    }
  }

  static void _schedule(MiniNotifier controller, Set<String>? ids) {
    if (_batchDepth == 0) {
      _dispatch(controller, ids);
      return;
    }

    final pending = _pendingChanges[controller];
    if (pending == null) {
      _pendingChanges[controller] = _PendingChange(ids);
      return;
    }
    pending.merge(ids);
  }

  static void _flush() {
    var iterations = 0;
    while (_pendingChanges.isNotEmpty) {
      if (++iterations > _maxFlushIterations) {
        _pendingChanges.clear();
        throw FlutterError(
          'Mini.batch flush exceeded $_maxFlushIterations iterations. '
          'Check controller workers for a re-entrant update loop.',
        );
      }

      final pending = Map<MiniNotifier, _PendingChange>.from(_pendingChanges);
      _pendingChanges.clear();

      for (final entry in pending.entries) {
        if (!entry.key.closed) {
          _dispatch(entry.key, entry.value.ids);
        }
      }
    }
  }

  static _MiniDependency _registerDependency({
    required MiniNotifier source,
    required MiniNotifier owner,
  }) {
    final path = _findPath(owner, source);
    if (path != null) {
      final cycle = <MiniNotifier>[source, ...path];
      final description = cycle.map((item) => item.runtimeType).join(' -> ');
      throw FlutterError('Circular MiniNotifier dependency: $description');
    }

    final owners = _dependencies.putIfAbsent(
      source,
      () => HashMap<MiniNotifier, int>.identity(),
    );
    owners[owner] = (owners[owner] ?? 0) + 1;
    return _MiniDependency(source, owner);
  }

  static void _unregisterDependency(_MiniDependency dependency) {
    final owners = _dependencies[dependency.source];
    if (owners == null) return;

    final count = owners[dependency.owner];
    if (count == null) return;
    if (count == 1) {
      owners.remove(dependency.owner);
    } else {
      owners[dependency.owner] = count - 1;
    }
    if (owners.isEmpty) {
      _dependencies.remove(dependency.source);
    }
  }

  static List<MiniNotifier>? _findPath(
    MiniNotifier start,
    MiniNotifier target,
  ) {
    final visited = HashSet<MiniNotifier>.identity();

    List<MiniNotifier>? visit(MiniNotifier current) {
      if (!visited.add(current)) return null;
      if (identical(current, target)) return <MiniNotifier>[current];

      for (final next in _dependencies[current]?.keys ??
          const Iterable<MiniNotifier>.empty()) {
        final tail = visit(next);
        if (tail != null) return <MiniNotifier>[current, ...tail];
      }
      return null;
    }

    return visit(start);
  }

  static void _dispatch(MiniNotifier controller, Set<String>? ids) {
    if (_dispatchStack.length >= _maxDispatchDepth) {
      throw FlutterError(
        'MiniNotifier update exceeded $_maxDispatchDepth nested dispatches. '
        'Check controller workers for an excessively deep dependency chain.',
      );
    }

    final cycleStart = _dispatchStack.indexOf(controller);
    if (cycleStart != -1) {
      final cycle = <MiniNotifier>[
        ..._dispatchStack.sublist(cycleStart),
        controller,
      ];
      final description = cycle.map((item) => item.runtimeType).join(' -> ');
      throw FlutterError('Circular MiniNotifier update: $description');
    }

    _dispatchStack.add(controller);
    try {
      controller._dispatchUpdate(ids);
    } finally {
      _dispatchStack.removeLast();
    }
  }
}

class _MiniDependency {
  const _MiniDependency(this.source, this.owner);

  final MiniNotifier source;
  final MiniNotifier owner;
}

class _PendingChange {
  _PendingChange(Set<String>? ids) : _ids = ids;

  Set<String>? _ids;

  Set<String>? get ids => _ids;

  void merge(Set<String>? ids) {
    if (_ids == null || ids == null) {
      _ids = null;
      return;
    }
    _ids!.addAll(ids);
  }
}
