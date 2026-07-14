# mini_builder

`mini_builder` 是一个轻量 Flutter 状态刷新工具，适合页面级 controller、局部刷新和深层 controller 注入。

## 特性

- `MiniNotifier`：controller 基类，提供生命周期、全量刷新和按 id 局部刷新。
- `MiniBuilder`：订阅 controller，并按需重建当前 Widget，支持 `id` 和 `shouldRebuild`。
- `MiniProvider`：把 controller 注入到子树，避免层层传参。
- 适合页面级状态、局部刷新和深层 controller 共享。

## 安装

本地开发时，在 `pubspec.yaml` 中通过 path 依赖引入：

```yaml
dependencies:
  mini_builder:
    path: ../mini_builder
```

按你的实际项目路径调整 `path` 即可。

业务代码统一导入：

```dart
import 'package:mini_builder/mini_builder.dart';
```

## 最小示例

```dart
class CounterController extends MiniNotifier {
  int count = 0;

  void increase() {
    count++;
    update();
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  late final CounterController controller;

  @override
  void initState() {
    super.initState();
    controller = CounterController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MiniBuilder<CounterController>(
          controller: controller,
          builder: (context, controller) {
            return Text('${controller.count}');
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increase,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## 生命周期

`MiniNotifier` 提供轻量生命周期钩子。业务开发者只需要覆写 `onInit()`、`onReady()` 和 `onClose()`，不要在业务逻辑中主动调用这些钩子：

```dart
class ProductController extends MiniNotifier {
  @override
  void onInit() {
    super.onInit();
    loadProduct();
  }

  @override
  void onReady() {
    super.onReady();
    // 第一帧后执行的补充初始化或收尾逻辑。
  }

  @override
  void onClose() {
    // 释放 timer、stream subscription、cancel token 等资源。
    super.onClose();
  }
}
```

controller 持有方需要负责创建和释放 controller。`onInit()` 会在 controller 构造完成后自动触发：

```dart
@override
void initState() {
  super.initState();
  controller = ProductController(productId);
}

@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

如需在第一帧渲染后执行逻辑，请把代码放在 `onReady()` 中。`onReady()` 由 `MiniBuilder` 在首帧后自动触发，业务侧不需要手动调用 ready 入口。

### 生命周期边界

- `onInit()`、`onReady()` 和 `onClose()` 是给业务开发者覆写的生命周期钩子。
- 持有 controller 的页面或封装需要负责创建和释放 controller。
- controller 构造完成后会自动触发 `onInit()`。
- `MiniBuilder` 会在首帧渲染后自动触发 `onReady()`。
- 生命周期钩子触发时会在非 release 模式下打印调试日志，release 模式不输出。
- `update([])` 不会触发任何监听器。
- `update()` 会通知普通 `addListener` 监听器和所有通过 `id` 订阅的 `MiniBuilder`。
- `update([id])` 只会通知对应 `id` 的 `MiniBuilder`，不会通知普通 `addListener`。
- controller 不建议持有 `BuildContext`。

## 按 id 局部刷新

```dart
class ProductIds {
  static const price = 'price';
  static const stock = 'stock';
}

void updatePrice() {
  price++;
  update([ProductIds.price]);
}
```

```dart
MiniBuilder<ProductController>(
  controller: controller,
  id: ProductIds.price,
  builder: (context, controller) {
    return Text('price: ${controller.price}');
  },
)
```

## shouldRebuild

`shouldRebuild` 用于在 controller 已通知时跳过本次重建：

```dart
MiniBuilder<CounterController>(
  controller: controller,
  shouldRebuild: (controller) => controller.count.isEven,
  builder: (context, controller) {
    return Text('${controller.count}');
  },
)
```

注意：

- `shouldRebuild` 只拿到当前 controller。
- 它不保存旧值，也不比较前后状态。
- 它适合简单条件，例如只在偶数、指定 tab、数据已准备好时刷新。
- 如果需要复杂 diff，请在 controller 内维护明确字段。

## MiniProvider 深层注入

当叶子节点需要访问 controller 时，如果不使用 `MiniProvider`，需要通过每一层构造参数传递：

```dart
// ❌ 层层传参
class OrderPage extends StatelessWidget {
  final OrderController controller;
  const OrderPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OrderHeader(controller: controller),       // 传递
        OrderBody(controller: controller),          // 传递
        OrderFooter(controller: controller),        // 传递
      ],
    );
  }
}

class OrderFooter extends StatelessWidget {
  final OrderController controller;
  const OrderFooter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MiniBuilder<OrderController>(
      controller: controller,
      id: OrderIds.totalPrice,
      builder: (_, controller) => Text('总价: ${controller.totalPrice}'),
    );
  }
}
```

使用 `MiniProvider` 在页面根部注入，叶子节点直接取用，中间层无需感知 controller：

```dart
// ✅ MiniProvider 注入
class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OrderHeader(),    // 无需传递
        const OrderBody(),      // 无需传递
        const OrderFooter(),    // 无需传递
      ],
    );
  }
}

class OrderFooter extends StatelessWidget {
  const OrderFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiniProvider.of<OrderController>(context);
    return MiniBuilder<OrderController>(
      controller: controller,
      id: OrderIds.totalPrice,
      builder: (_, controller) => Text('总价: ${controller.totalPrice}'),
    );
  }
}
```

页面根部注入：

```dart
MiniProvider<ProductController>(
  controller: controller,
  child: const ProductDetailView(),
)
```

深层组件读取：

```dart
final controller = MiniProvider.of<ProductController>(context);
```

可选读取：

```dart
final controller = MiniProvider.maybeOf<ProductController>(context);
```

### 多 controller 嵌套

不同类型 controller 可以直接嵌套：

```dart
MiniProvider<UserController>(
  controller: userController,
  child: MiniProvider<CartController>(
    controller: cartController,
    child: const PageContent(),
  ),
)
```

分别读取：

```dart
final user = MiniProvider.of<UserController>(context);
final cart = MiniProvider.of<CartController>(context);
```

同类型 controller 嵌套时，`MiniProvider.of<T>()` 会返回最近的那个：

```dart
MiniProvider<ProductController>(
  controller: outer,
  child: MiniProvider<ProductController>(
    controller: inner,
    child: const ProductPanel(),
  ),
)
```

`ProductPanel` 读取到的是 `inner`。如果同一棵子树需要两个同类型 controller，优先改成不同 controller 类型，或显式通过构造参数传入，不建议提前引入 tag 机制。

## 商品详情页场景

相似商品点击进入新详情页时，通常是新路由、新页面实例、新 controller：

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ProductDetailPage(productId: similarProductId),
  ),
);
```

每个详情页自己创建并注入 controller：

```dart
class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final ProductController controller;

  @override
  void initState() {
    super.initState();
    controller = ProductController(widget.productId);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniProvider<ProductController>(
      controller: controller,
      child: const ProductDetailView(),
    );
  }
}
```

旧页面和新页面分别处在不同路由子树中，相同类型 controller 不会互相覆盖。

## 常见误区

### ❌ 在 build 中创建 controller

每次 rebuild 都会创建新实例，导致状态丢失、监听泄漏：

```dart
// ❌ 错误
@override
Widget build(BuildContext context) {
  final controller = OrderController();  // 每次 rebuild 都会重建
  return MiniBuilder<OrderController>(controller: controller, ...);
}
```

```dart
// ✅ 正确：在 StatefulWidget 的 createState 中创建
late final OrderController controller;

@override
void initState() {
  super.initState();
  controller = OrderController();
}

@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

### ❌ controller 持有 BuildContext

`BuildContext` 持有可能导致内存泄漏和生命周期异常：

```dart
// ❌ 错误
class OrderController extends MiniNotifier {
  BuildContext context;  // 不要这样做

  void load() {
    Navigator.of(context).push(...);  // 危险
  }
}
```

```dart
// ✅ 正确：在 Widget 层处理导航等 Context 操作
class OrderPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MiniBuilder<OrderController>(
      controller: controller,
      builder: (_, controller) {
        return ElevatedButton(
          onPressed: () => Navigator.of(context).push(...),
          child: const Text('下一步'),
        );
      },
    );
  }
}
```

### 在 onInit 中请求数据并通知 UI

`onInit()` 可以直接发起 API 请求，并在数据更新后调用 `update()`。如果初始化由 `MiniBuilder` 触发，它会先完成订阅；如果 controller 更早完成初始化，页面首帧会直接读取 controller 的最新状态：

```dart
class OrderController extends MiniNotifier {
  Order? order;
  Object? loadError;

  @override
  void onInit() async {
    super.onInit();
    late final Order nextOrder;
    try {
      nextOrder = await orderApi.fetch();
    } catch (error) {
      if (closed) return;

      loadError = error;
      update();
      return;
    }
    if (closed) return;

    order = nextOrder;
    update();
  }
}
```

`onInit()` 的生命周期签名是 `void`。写成 `async` 后，框架不会等待其中的 Future；`onReady()` 仍会在首帧后触发，可能早于 API 返回。请求异常需要在 `onInit()` 内处理，不能依赖生命周期调用方捕获。

`onReady()` 仍适合依赖首帧渲染结果的逻辑，不需要为了刷新页面把普通 API 请求延后到 `onReady()`。

可运行示例见 [`example/lib/on_init_api_example.dart`](example/lib/on_init_api_example.dart)，对应验证见 [`example/test/on_init_api_example_test.dart`](example/test/on_init_api_example_test.dart)。示例包含两个不同 controller 的嵌套 `MiniBuilder`。两个 controller 的订阅和通知彼此独立，但外层 Builder 重建时，内层仍会遵循 Flutter 的子树重建规则。

example 通过 [`ExampleLogManager`](example/lib/example_log_manager.dart) 输出结构化调试日志，包括请求开始、成功或失败、耗时、状态刷新和 Builder 重建次数。日志不记录 API 返回内容和异常消息。默认只在非 release 模式输出；企业应用应通过 `configure()` 接入经过审批的日志采集器，并按所在环境的脱敏和留存策略处理。

Android 示例可在 `example` 目录执行 `flutter run -d <device-id>` 启动。当前 Android 宿主使用示例 applicationId 和 debug 签名，仅用于功能验证；接入企业发布流程前必须替换为正式包名、签名配置和对应的 CI 密钥管理方案。

### ❌ 用 MiniProvider 做跨路由全局共享

`MiniProvider` 注入的是 widget 子树，不是全局单例。跨路由共享应使用全局 controller 或状态管理方案：

```dart
// ❌ 错误：期望另一个路由的页面能通过 MiniProvider.of 读取到
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const AnotherPage()),
);
// AnotherPage 中 MiniProvider.of<T>(context) 找不到
```

```dart
// ✅ 正确：新路由需要自己的 controller 实例
class AnotherPage extends StatefulWidget {
  @override
  State<AnotherPage> createState() => _AnotherPageState();
}

class _AnotherPageState extends State<AnotherPage> {
  late final controller = OrderController();
  // ...
}
```

## 能力边界

适合：

- 页面级状态管理。
- 表单、详情、列表、设置页。
- 页面内多个区域共享 controller。
- 全量刷新和 id 局部刷新。
- 简单条件重建。

不负责：

- 自动依赖注入。
- 自动创建和销毁 controller。
- 全局状态管理。
- 路由守卫和中间件。
- 副作用队列。
- 数据缓存同步和离线策略。
