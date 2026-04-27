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
    controller = CounterController()..init();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniProvider<CounterController>(
      controller: controller,
      child: Scaffold(
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
      ),
    );
  }
}
```

## 生命周期

`MiniNotifier` 提供轻量生命周期：

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
    super.onClose();
    // 释放 timer、stream subscription、cancel token 等资源。
  }
}
```

页面负责触发生命周期：

```dart
@override
void initState() {
  super.initState();
  controller = ProductController(productId)..init();
}

@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

如需在第一帧渲染后执行逻辑，可在 `initState` 中调度 `ready()`：

```dart
@override
void initState() {
  super.initState();
  controller = ProductController(productId)..init();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    controller.ready();
  });
}
```

### 生命周期边界

- `init()` 只触发一次 `onInit()`。
- `ready()` 只触发一次 `onReady()`，需页面自行调度。
- `dispose()` 只触发一次 `onClose()`。
- `MiniBuilder` 不会自动调用 `init()`、`ready()` 或 `dispose()`。
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
    controller = ProductController(widget.productId)..init();
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
