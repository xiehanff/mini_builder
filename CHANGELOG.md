## 0.2.1

- `MiniBuilder` 触发初始化时会先订阅 controller，支持在 `onInit()` 请求数据后调用 `update()` 刷新页面。
- example App 增加不同 controller 的嵌套 `MiniBuilder`，两个 controller 都在 `onInit` 请求 API、处理异常并调用 `update()`。
- README 补充异步 `onInit` 与 `onReady` 的执行顺序，以及嵌套 Builder 的子树重建边界。
- example App 增加可配置的结构化调试日志和 Android 启动宿主。
- 重命名 `_init` 为 `_ensureInitialized`，更清晰表达幂等初始化语义。
- 补充关键设计决策的内联注释：双触发初始化路径、`_notifyIdListeners` 的 contains 守卫、`onReady` 触发约束。

## 0.2.0

- 修复 `MiniBuilder` 在 controller 切换时未正确触发新 controller 生命周期（`onInit` / `onReady`）的问题。
- 修复 `MiniBuilder` 在 `id` 变更时未正确取消旧 id 订阅的问题。
- `initState` 中显式调用 `controller._init()`，确保订阅前 controller 已完成初始化。
- 重构 `didUpdateWidget` 逻辑，分离 controller 变更与 id 变更的处理路径。

## 0.1.0

- Initial release.
- `MiniNotifier`: controller base with lifecycle (`onInit`, `onReady`, `onClose`), full rebuild (`update()`), and id-based partial rebuild (`update([id])`).
- `MiniBuilder`: subscribe to a controller and rebuild on demand, supporting optional `id` and `shouldRebuild`.
- `MiniProvider`: inject controller into the widget tree via `InheritedWidget`, with `of<T>()` and `maybeOf<T>()` lookups.
