# mini_builder Agent Quickstart

This guide is for coding agents that need to add or modify Flutter business code using `mini_builder`. It describes the intended ownership model and the smallest API surface needed for common changes.

## Core rules

`mini_builder` separates state ownership, dependency injection, and widget rebuilding:

| Need | Use |
| --- | --- |
| Page or feature state | A `MiniNotifier` subclass owned by the page or feature widget |
| Widget refresh | `MiniBuilder<T>` |
| App-wide dependency injection | `MiniProvider<T>(value: object, child: ...)` at the composition root |
| Controller-to-controller dependency | Constructor parameters |
| Dependency refresh | `watch`, `watchAll`, `debounce`, or `interval` |
| Multiple writes in one business action | `Mini.batch(() { ... })` |

There is no `put` / `find` service locator. There is also no `MiniProvider.value` constructor. The current provider API is the regular constructor with a named `value` parameter.

## Design positioning

Use `mini_builder` when code should make ownership and dependencies reviewable from the widget tree. Compared with the common GetX service-locator style, it avoids hidden `put/find` lookups, tag collisions, unclear controller ownership, and rebuilds caused by dependencies that are discovered far from the widget. It also gives dependency workers a managed lifecycle, cycle detection, batching, and callback error isolation.

The package does not try to replace every part of an application framework. It deliberately keeps routing, persistence, networking, and global composition in the application. Its design principles are:

1. **Explicit over implicit**: constructor injection and provider scope are easier to inspect and replace in tests.
2. **Owner over registry**: the creator owns `dispose()`; a widget builder does not silently create a global singleton.
3. **Small refresh boundaries**: `MiniBuilder`, ids, and `shouldRebuild` state exactly which UI region can rebuild.
4. **Managed dependency graphs**: workers declare edges, coalesce related changes, reject cycles, and are removed with their owner.
5. **Safe asynchronous boundaries**: `update()` is a no-op after disposal, while business code checks `closed` before using resources released in `onClose`.

Do not describe `mini_builder` as universally better than GetX. Describe it as a better fit when explicit composition, Flutter-native scope, direct testing, and predictable lifetimes matter more than global convenience APIs.

## Minimal page state

Create and dispose a controller in the widget that owns it:

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
    return MiniBuilder<CounterController>(
      controller: controller,
      builder: (context, controller) {
        return Text('${controller.count}');
      },
    );
  }
}
```

Use the controller's values directly in the builder. The controller calls `update()` after changing state; the widget does not call `setState()` for that controller.

## App-wide state and explicit dependencies

Create long-lived services once near the application root. `MiniProvider` only exposes the object; the owner still disposes it:

```dart
class AppServices {
  AppServices()
      : auth = AuthController(),
        cart = CartController();

  final AuthController auth;
  final CartController cart;

  void dispose() {
    auth.dispose();
    cart.dispose();
  }
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final services = AppServices();

  @override
  void dispose() {
    services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniProvider<AppServices>(
      value: services,
      child: const MaterialApp(home: CheckoutPage()),
    );
  }
}
```

Read the nearest value from a widget with `MiniProvider.of<T>(context)` or use `MiniProvider.maybeOf<T>(context)` when it is optional. Pass dependencies into a controller constructor instead of looking them up inside the controller:

```dart
class CheckoutController extends MiniNotifier {
  CheckoutController({required this.auth, required this.cart});

  final AuthController auth;
  final CartController cart;

  String summary = '';

  @override
  void onInit() {
    super.onInit();
    watchAll(
      <MiniWatchSource>[
        MiniWatchSource(auth, ids: <String>['session']),
        MiniWatchSource(cart, ids: <String>['items']),
      ],
      fireImmediately: true,
      onChanged: (_) {
        summary = '${auth.signedIn}: ${cart.itemCount}';
        update(<String>['summary']);
      },
    );
  }
}
```

## Refresh API

| Call | Result |
| --- | --- |
| `update()` | Full refresh: regular listeners and all id listeners |
| `update([id])` | Refresh only builders subscribed to that id |
| `update([])` | Notifies nobody and asserts in debug mode; usually a bug |
| `Mini.batch(() { ... })` | Merges writes from the same controllers before dispatching |

Keep ids in constants to avoid collisions:

```dart
abstract final class CartIds {
  static const items = 'cart.items';
}
```

Bind an id in the UI with `MiniBuilder.id`:

```dart
MiniBuilder<CartController>(
  controller: cart,
  id: CartIds.items,
  builder: (context, cart) => Text('${cart.itemCount}'),
)
```

Use `shouldRebuild` when the controller receives a notification but a particular widget only needs to rebuild for some values:

```dart
MiniBuilder<CartController>(
  controller: cart,
  shouldRebuild: (cart) => cart.itemCount.isEven,
  builder: (context, cart) => Text('${cart.itemCount}'),
)
```

## Worker selection

```dart
owner.watch(source, onChanged: (change) { ... });
owner.watch(source, ids: <String>['items'], onChanged: (change) { ... });
owner.watchAll(sources, onChanged: (changes) { ... });
owner.debounce(source, duration: const Duration(milliseconds: 300), onChanged: (change) { ... });
owner.interval(source, duration: const Duration(milliseconds: 300), onChanged: (change) { ... });
```

- `watch` observes one controller.
- `watchAll` observes multiple controllers. With the default `coalesce: true`, synchronous changes are delivered in one callback.
- `debounce` waits until the source stops changing.
- `interval` delivers at most one callback per duration.
- All workers belong to the owner controller and are removed when the owner is disposed. Keep the returned `MiniWorker` only when the business flow needs to stop a subscription early.
- Circular dependencies are rejected during registration. Use a coordinator controller when two controllers need to update each other.

`fireImmediately: true` invokes the callback during registration. For `watchAll`, the immediate callback receives an empty `List<MiniChange>` because no source has emitted a change yet.

## Lifecycle rules

- Override `onInit`, `onReady`, and `onClose`; do not call them manually.
- `onInit` runs once after construction or when the first `MiniBuilder` attaches.
- `onReady` is triggered by `MiniBuilder` after the first frame.
- Release timers, stream subscriptions, and external resources in `onClose`.
- Do not store `BuildContext` in a controller.
- A controller owner, not `MiniBuilder` or `MiniProvider`, calls `dispose()`.
- Async callbacks must check `closed` before writing state or calling `update()`.

## Agent workflow

1. Find the widget or feature that owns the controller.
2. Add fields and mutations to a `MiniNotifier` subclass, keeping UI code out of the controller.
3. Add stable id constants for partial refreshes.
4. Pass cross-controller dependencies through constructors.
5. Register workers in `onInit` and release non-worker resources in `onClose`.
6. Use `MiniProvider<T>(value: object, child: ...)` only at the composition boundary.
7. Add or update a focused widget or controller test.
8. Run `flutter analyze` and `flutter test` for the package and its example.

Avoid putting controllers, feature widgets, or business mutations in `lib/main.dart`; keep that file as the application entry point and move feature code into named files or feature directories.
