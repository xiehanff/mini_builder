# Mini Builder 边界行为说明

本文补充说明 `MiniNotifier` / `MiniBuilder` 在异常、销毁和局部刷新场景下的确定语义。

## `update([...])` 的重复 id

同一次 `update([...])` 调用中，重复 id 会自动去重：

```dart
controller.update(['price', 'price', 'stock']);
```

等价于：

```dart
controller.update(['price', 'stock']);
```

因此同一个 id 在一次 update transaction 中最多通知一次。

## id listener 的异常隔离

按 id 通知时，单个 listener 抛出的异常会通过 Flutter 的错误报告机制上报，但不会阻断同一轮中的其他 listener。

这使按 id 更新与 `ChangeNotifier.notifyListeners()` 的容错语义保持一致：一个 Builder 的异常不应导致其他 Builder 收不到本轮通知。

## `onClose()` 抛异常时仍保证框架清理

`MiniNotifier.dispose()` 会通过 `try/finally` 保证框架自身清理完成。

即使业务覆写的 `onClose()` 抛出异常，Mini Builder 仍会：

- 清理 id listeners；
- 调用 `ChangeNotifier.dispose()`；
- 保持 `closed == true`；
- 后续 `update()` 安全地成为 no-op。

业务覆写 `onClose()` 时仍应遵守 `@mustCallSuper`：

```dart
@override
void onClose() {
  subscription.cancel();
  super.onClose();
}
```

## 已销毁 controller

Debug 模式下，把已经 dispose 的 controller 传给一个新挂载的 `MiniBuilder` 会触发断言。

这样可以把生命周期错误尽早暴露在 Widget 挂载位置，而不是等到后续访问 `TextEditingController`、`AnimationController` 等已销毁资源时才报错。

controller 销毁后直接调用 `MiniNotifier.update()` 仍然是安全的 no-op，但业务代码在异步 `await` 返回后仍应先检查：

```dart
if (closed) return;
```

再访问 controller 持有的 Flutter 资源。

## `initialized` / `readyCalled` 的含义

`initialized == true` 表示 `onInit()` 已经开始执行过；`readyCalled == true` 表示 `onReady()` 已经开始执行过。

它们不表示异步业务初始化已经成功完成。生命周期 hook 抛异常时，框架不会自动重试。

## MiniProvider 的职责

`MiniProvider` 只负责在 Widget 子树中提供 controller 引用：

- 不监听 `MiniNotifier`；
- 不因为 `controller.update()` 自动刷新读取它的 Widget；
- 不创建 controller；
- 不负责 dispose controller；
- 不触发 `onReady()`。

需要响应状态变化时，应组合：

```dart
final controller = MiniProvider.of<OrderController>(context);

return MiniBuilder<OrderController>(
  controller: controller,
  builder: (_, controller) => ...,
);
```

## CI

仓库的 Flutter CI 会在 PR 和指定分支 push 时执行：

```text
flutter pub get
flutter analyze
flutter test
```

边界行为对应的回归测试位于 `test/mini_notifier_test.dart`、`test/mini_builder_widget_test.dart` 和 `test/async_disposal_resource_test.dart`。
