# mini_builder

[`中文文档`](./README_zh.md)

`mini_builder` is a lightweight Flutter state refresh utility, suitable for page-level controllers, partial refreshes, and deep controller injection.

## Features

- `MiniNotifier`: Base class for controllers, providing lifecycle hooks, full refresh, and per-id partial refresh.
- `MiniBuilder`: Subscribes to a controller and rebuilds the current Widget on demand, supporting `id` and `shouldRebuild`.
- `MiniProvider`: Injects a controller into the widget subtree, avoiding prop drilling.
- Ideal for page-level state, partial refreshes, and deep controller sharing.

## Installation

For local development, add as a path dependency in `pubspec.yaml`:

```yaml
dependencies:
  mini_builder:
    path: ../mini_builder
```

Adjust the `path` according to your actual project structure.

Import in business code:

```dart
import 'package:mini_builder/mini_builder.dart';
```

## Minimal Example

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

## Lifecycle

`MiniNotifier` provides lightweight lifecycle hooks. Business developers only need to override `onInit()`, `onReady()`, and `onClose()`. Do not call these hooks manually in business logic:

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
    // Supplementary initialization or cleanup logic executed after the first frame.
  }

  @override
  void onClose() {
    // Release resources like timers, stream subscriptions, cancel tokens, etc.
    super.onClose();
  }
}
```

The controller owner is responsible for creating and disposing the controller. `onInit()` is automatically triggered after the controller is constructed:

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

If you need to execute logic after the first frame renders, place the code in `onReady()`. `onReady()` is automatically triggered by `MiniBuilder` after the first frame. Business code does not need to manually call a ready entry point.

### Lifecycle Boundaries

- `onInit()`, `onReady()`, and `onClose()` are lifecycle hooks for business developers to override.
- The page or widget that holds the controller is responsible for creating and disposing it.
- `onInit()` is automatically triggered after the controller is constructed.
- `MiniBuilder` automatically triggers `onReady()` after the first frame renders.
- Lifecycle hooks print debug logs in non-release mode; release mode produces no output.
- `update([])` does not trigger any listeners.
- `update()` notifies regular `addListener` listeners and all `MiniBuilder`s subscribed via `id`.
- `update([id])` only notifies the `MiniBuilder` with the corresponding `id`, not regular `addListener`s.
- Controllers should not hold `BuildContext`.

## Partial Refresh by ID

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

`shouldRebuild` is used to skip a rebuild when the controller has already notified:

```dart
MiniBuilder<CounterController>(
  controller: controller,
  shouldRebuild: (controller) => controller.count.isEven,
  builder: (context, controller) {
    return Text('${controller.count}');
  },
)
```

Note:

- `shouldRebuild` only receives the current controller.
- It does not save old values or compare previous and current states.
- It is suitable for simple conditions, such as rebuilding only on even numbers, specific tabs, or when data is ready.
- If you need complex diffing, maintain explicit fields within the controller.

## MiniProvider Deep Injection

Inject at page root:

```dart
MiniProvider<ProductController>(
  controller: controller,
  child: const ProductDetailView(),
)
```

Read in deep components:

```dart
final controller = MiniProvider.of<ProductController>(context);
```

Optional read:

```dart
final controller = MiniProvider.maybeOf<ProductController>(context);
```

### Multiple Controller Nesting

Different controller types can be nested directly:

```dart
MiniProvider<UserController>(
  controller: userController,
  child: MiniProvider<CartController>(
    controller: cartController,
    child: const PageContent(),
  ),
)
```

Read separately:

```dart
final user = MiniProvider.of<UserController>(context);
final cart = MiniProvider.of<CartController>(context);
```

When nesting controllers of the same type, `MiniProvider.of<T>()` returns the nearest one:

```dart
MiniProvider<ProductController>(
  controller: outer,
  child: MiniProvider<ProductController>(
    controller: inner,
    child: const ProductPanel(),
  ),
)
```

`ProductPanel` reads `inner`. If you need two controllers of the same type in the same subtree, prefer refactoring to different controller types or passing explicitly via constructor parameters. Introducing a tag mechanism prematurely is not recommended.

## Product Detail Page Scenario

When clicking on a similar product to enter a new detail page, it is typically a new route, new page instance, new controller:

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ProductDetailPage(productId: similarProductId),
  ),
);
```

Each detail page creates and injects its own controller:

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

The old page and new page are in different route subtrees, so controllers of the same type will not override each other.

## Capability Boundaries

Suitable for:

- Page-level state management.
- Forms, details, lists, settings pages.
- Sharing controllers across multiple areas within a page.
- Full refresh and per-id partial refresh.
- Simple conditional rebuilding.

Not responsible for:

- Automatic dependency injection.
- Automatic controller creation and disposal.
- Global state management.
- Route guards and middleware.
- Side effect queues.
- Data cache synchronization and offline strategies.
