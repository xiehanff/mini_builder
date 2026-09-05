## 0.3.0

### ⚠️ Breaking Changes

- **移除** `MiniProvider(controller: ...)` 旧构造函数和 `controller` getter
- 现在使用 `MiniProvider(value: ...)` 构造函数

#### 迁移指南

替换旧写法：
```dart
// ❌ 旧写法（已移除）
MiniProvider<MyController>(
  controller: myController,
  child: MyWidget(),
)

// 以及
final controller = MiniProvider.of<MyController>(context).controller;
```

使用新写法：
```dart
// ✅ 新写法
MiniProvider<MyController>(
  value: myController,
  child: MyWidget(),
)

// 读取方式不变
final controller = MiniProvider.of<MyController>(context);
```

### 新增功能

- 新增 `MiniProvider` 用于显式依赖注入，无需 `put/find` 式全局服务定位器
- 新增 controller 持有的依赖 worker：`watch`、`watchAll`、`debounce`、`interval`，订阅和计时器随 controller 销毁自动取消
- 新增 `Mini.batch()` 合并同一 controller 在单次业务操作中的多次 `update()` 调用
- 拒绝循环 worker 依赖，并一致地报告 worker 回调失败（包括防抖、节流和合并的回调）
- 限制嵌套更新派发深度和批处理刷新迭代次数，防止重入更新循环
- 新增示例和验证：根部 `MiniProvider`、构造函数注入、`watchAll`、`Mini.batch()`
- 所有公开 API 文档注释完全中文化

### 已知问题

- 示例 App 在某些 Flutter 版本的测试环境中可能遇到 shader 资源加载错误（`ink_sparkle.frag`），这是 Flutter 框架已知问题，不影响实际运行和库的核心功能

## 0.2.1

- `MiniBuilder` 触发初始化时会先订阅 controller，支持在 `onInit()` 请求数据后调用 `update()` 刷新页面。
- example App 增加不同 controller 的嵌套 `MiniBuilder`，两个 controller 都在 `onInit` 请求 API、处理异常并调用 `update()`。
- README 补充 `onInit` 的双初始化路径、异步 `onInit` 与 `onReady` 的执行顺序、销毁后的异步回调保护，以及嵌套 Builder 的子树重建边界。
- 增加异步请求晚于 controller 销毁返回的测试，分别覆盖 `update()` 安全空操作、`closed` 守卫，以及误用已释放的 `TextEditingController` 和 `AnimationController`。
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
