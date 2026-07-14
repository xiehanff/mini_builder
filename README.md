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

When a leaf node needs access to a controller, without `MiniProvider` you must pass it through every layer of constructor parameters:

```dart
// ❌ Prop drilling
class OrderPage extends StatelessWidget {
  final OrderController controller;
  const OrderPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OrderHeader(controller: controller),       // passing through
        OrderBody(controller: controller),          // passing through
        OrderFooter(controller: controller),        // passing through
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
      builder: (_, controller) => Text('Total: ${controller.totalPrice}'),
    );
  }
}
```

Using `MiniProvider` at the page root, leaf nodes can access the controller directly — intermediate layers don't need to know about it:

```dart
// ✅ MiniProvider injection
class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OrderHeader(),    // no passing needed
        const OrderBody(),      // no passing needed
        const OrderFooter(),    // no passing needed
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
      builder: (_, controller) => Text('Total: ${controller.totalPrice}'),
    );
  }
}
```

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

## Common Pitfalls

### ❌ Creating a controller in build

Every rebuild creates a new instance, causing state loss and listener leaks:

```dart
// ❌ Wrong
@override
Widget build(BuildContext context) {
  final controller = OrderController();  // new instance on every rebuild
  return MiniBuilder<OrderController>(controller: controller, ...);
}
```

```dart
// ✅ Correct: create in StatefulWidget's createState
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

### ❌ Controller holding BuildContext

Holding `BuildContext` may cause memory leaks and lifecycle issues:

```dart
// ❌ Wrong
class OrderController extends MiniNotifier {
  BuildContext context;  // don't do this

  void load() {
    Navigator.of(context).push(...);  // dangerous
  }
}
```

```dart
// ✅ Correct: handle Context-dependent operations in the Widget layer
class OrderPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MiniBuilder<OrderController>(
      controller: controller,
      builder: (_, controller) {
        return ElevatedButton(
          onPressed: () => Navigator.of(context).push(...),
          child: const Text('Next'),
        );
      },
    );
  }
}
```

### Requesting data and notifying the UI in onInit

You can request data in `onInit()` and call `update()` after the data changes. When `MiniBuilder` triggers initialization, it subscribes first. If the controller was initialized earlier, the first build reads its latest state directly:

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

The lifecycle signature of `onInit()` is `void`. Making it `async` does not make the framework await its Future. `onReady()` still runs after the first frame and may run before the API returns. Handle request errors inside `onInit()` instead of relying on the lifecycle caller to catch them.

`onReady()` remains appropriate for logic that depends on the first rendered frame. Regular API requests do not need to be delayed until `onReady()` just to refresh the UI.

See [`example/lib/on_init_api_example.dart`](example/lib/on_init_api_example.dart) for a runnable example and [`example/test/on_init_api_example_test.dart`](example/test/on_init_api_example_test.dart) for its verification. The example nests `MiniBuilder`s backed by two different controllers. Their subscriptions and notifications are independent, but rebuilding the outer builder still rebuilds its subtree according to Flutter's widget-tree rules.

The example uses [`ExampleLogManager`](example/lib/example_log_manager.dart) for structured debug logs covering request start, success or failure, elapsed time, state updates, and builder rebuild counts. It does not log API payloads or exception messages. Logging is disabled in release mode by default. Enterprise applications should connect an approved sink through `configure()` and apply their environment's redaction and retention policies.

Run the Android example from the `example` directory with `flutter run -d <device-id>`. The generated Android host currently uses a sample application ID and debug signing and is intended only for functional verification. Replace the package name, signing configuration, and CI secret-management setup before an enterprise release.

### ❌ Using MiniProvider for cross-route global sharing

`MiniProvider` injects into the widget subtree, not a global singleton. For cross-route sharing, use a global controller or state management solution:

```dart
// ❌ Wrong: expecting another route's page to read via MiniProvider.of
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const AnotherPage()),
);
// AnotherPage won't find MiniProvider.of<T>(context)
```

```dart
// ✅ Correct: each route needs its own controller instance
class AnotherPage extends StatefulWidget {
  @override
  State<AnotherPage> createState() => _AnotherPageState();
}

class _AnotherPageState extends State<AnotherPage> {
  late final controller = OrderController();
  // ...
}
```

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
