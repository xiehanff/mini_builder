# mini_builder

[`中文文档`](./README_CN.md)

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

The controller owner is responsible for creating and disposing the controller. After construction, initialization is scheduled in a microtask. If the controller is attached to a `MiniBuilder` first, `MiniBuilder` subscribes before triggering initialization. Both paths share an idempotency guard, so `onInit()` runs only once:

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
- After construction, `onInit()` is triggered by the scheduled microtask or by the first attached `MiniBuilder`, whichever initializes the controller first; it runs only once.
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

### Advanced: Comparing Previous and Current Values

If you need to compare previous and current values, maintain state history in the controller:

```dart
class ProductController extends MiniNotifier {
  int _price = 0;
  int _previousPrice = 0;

  int get price => _price;
  bool get priceChanged => _price != _previousPrice;

  void updatePrice(int newPrice) {
    _previousPrice = _price;
    _price = newPrice;
    update();
  }
}

// Use in MiniBuilder
MiniBuilder<ProductController>(
  controller: controller,
  shouldRebuild: (controller) => controller.priceChanged,
  builder: (context, controller) {
    return Text('Price: ${controller.price}');
  },
)
```

Or use value objects to encapsulate state:

```dart
class ProductState {
  final int price;
  final String name;

  const ProductState({required this.price, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductState && price == other.price && name == other.name;

  @override
  int get hashCode => Object.hash(price, name);
}

class ProductController extends MiniNotifier {
  ProductState _state = const ProductState(price: 0, name: '');
  ProductState _previousState = const ProductState(price: 0, name: '');

  ProductState get state => _state;

  void updateState(ProductState newState) {
    _previousState = _state;
    _state = newState;
    update();
  }
}

MiniBuilder<ProductController>(
  controller: controller,
  shouldRebuild: (controller) => controller.state != controller._previousState,
  builder: (context, controller) {
    return Text('${controller.state.name}: ${controller.state.price}');
  },
)
```

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

### Async responses after disposal

A network request may complete after its page and controller have been disposed. The relevant behaviors are different:

- Calling `MiniNotifier.update()` after disposal is safe; it detects `closed` and returns without notifying listeners.
- Flutter resources owned by the controller, such as `TextEditingController` and `AnimationController`, are no longer usable after they have been disposed.
- Check `closed` immediately after every `await`, before mutating state or accessing owned resources.
- When the HTTP client supports cancellation, cancel in-flight requests in `onClose()`.

```dart
Future<void> loadProduct() async {
  final result = await productApi.fetch();

  if (closed) return;

  searchController.text = result.name;
  entranceAnimation.forward();
  product = result;
  update();
}

@override
void onClose() {
  searchController.dispose();
  entranceAnimation.dispose();
  requestCancelToken.cancel();
  super.onClose();
}
```

Tests for the safe and unsafe paths are in [`test/async_disposal_resource_test.dart`](test/async_disposal_resource_test.dart).

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

## FAQ

**Q: Why doesn't `update()` in `onInit` refresh the UI?**

A: `onInit` is triggered immediately after construction, before `MiniBuilder` subscribes. Call `update()` in `onReady`, or directly after async operations complete.

---

**Q: What's the difference between `update([])` and `update()`?**

A:
- `update()` - Full refresh: notifies all listeners (global and all id listeners)
- `update([])` - Empty list notifies no listeners (triggers assertion in debug mode; usually a logic error)
- `update(['id'])` - Partial refresh: only notifies specified id listeners

---

**Q: Can I use MiniNotifier in a global singleton?**

A: Yes, but you must manually manage its lifecycle. MiniNotifier is better suited for page-level controllers. For global state, consider Provider or other global state management solutions.

---

**Q: Does MiniBuilder automatically dispose the controller?**

A: No. Controller creation and disposal are the responsibility of the business layer (typically StatefulWidget). MiniBuilder only subscribes; it doesn't own the controller.

---

**Q: Can I use multiple MiniBuilders with the same controller?**

A: Yes. Multiple MiniBuilders can subscribe to the same controller. `onReady()` will only be called once after the first frame, regardless of how many MiniBuilders are attached.

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

### ❌ Calling update to notify UI in onInit

`onInit()` fires right after construction, before `MiniBuilder` has subscribed — `update()` produces no refresh:

```dart
// ❌ Wrong
class OrderController extends MiniNotifier {
  @override
  void onInit() {
    super.onInit();
    loadOrder();  // if this calls update(), UI won't refresh
  }
}
```

```dart
// ✅ Correct: notify UI in onReady
class OrderController extends MiniNotifier {
  @override
  void onInit() {
    super.onInit();
    loadOrder();  // start request
  }

  @override
  void onReady() {
    super.onReady();
    // After the first frame MiniBuilder is subscribed; update() works correctly
  }
}
```

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
