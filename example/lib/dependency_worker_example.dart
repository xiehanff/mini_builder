import 'package:flutter/material.dart';
import 'package:mini_builder/mini_builder.dart';

abstract final class DemoAuthIds {
  static const session = 'demo.auth.session';
}

abstract final class DemoCartIds {
  static const items = 'demo.cart.items';
}

abstract final class DemoCheckoutIds {
  static const summary = 'demo.checkout.summary';
}

/// App-wide dependencies created once by the application root.
class DemoAppServices {
  DemoAppServices()
      : auth = DemoAuthController(),
        cart = DemoCartController();

  final DemoAuthController auth;
  final DemoCartController cart;

  void dispose() {
    auth.dispose();
    cart.dispose();
  }
}

class DemoAuthController extends MiniNotifier {
  bool signedIn = false;

  void toggleSession() {
    signedIn = !signedIn;
    update(<String>[DemoAuthIds.session]);
  }
}

class DemoCartController extends MiniNotifier {
  int itemCount = 0;

  void addItem() {
    itemCount++;
    update(<String>[DemoCartIds.items]);
  }
}

/// A page controller that explicitly depends on two app-wide controllers.
class DemoCheckoutController extends MiniNotifier {
  DemoCheckoutController({
    required DemoAuthController auth,
    required DemoCartController cart,
  })  : _auth = auth,
        _cart = cart;

  final DemoAuthController _auth;
  final DemoCartController _cart;

  String summary = '正在计算结算结果…';
  int recalculationCount = 0;

  @override
  void onInit() {
    super.onInit();
    watchAll(
      <MiniWatchSource>[
        MiniWatchSource(_auth, ids: <String>[DemoAuthIds.session]),
        MiniWatchSource(_cart, ids: <String>[DemoCartIds.items]),
      ],
      fireImmediately: true,
      onChanged: (_) => _recalculate(),
    );
  }

  void _recalculate() {
    recalculationCount++;
    if (!_auth.signedIn) {
      summary = '请先登录';
    } else {
      summary = '已登录，购物车 ${_cart.itemCount} 件';
    }
    update(<String>[DemoCheckoutIds.summary]);
  }
}

/// Demonstrates root [MiniProvider.value], constructor injection, [watchAll],
/// and [Mini.batch] without a service locator.
class DependencyWorkerExampleEntry extends StatelessWidget {
  const DependencyWorkerExampleEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return DependencyWorkerExample(
      services: MiniProvider.of<DemoAppServices>(context),
    );
  }
}

class DependencyWorkerExample extends StatefulWidget {
  const DependencyWorkerExample({
    super.key,
    required this.services,
  });

  final DemoAppServices services;

  @override
  State<DependencyWorkerExample> createState() =>
      _DependencyWorkerExampleState();
}

class _DependencyWorkerExampleState extends State<DependencyWorkerExample> {
  late final DemoCheckoutController _controller = DemoCheckoutController(
    auth: widget.services.auth,
    cart: widget.services.cart,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '跨 Controller 依赖与全局状态',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'App 根部通过 MiniProvider.value 提供登录态和购物车；'
              '结算页 controller 经构造函数注入它们，并用 watchAll 自动重算。',
            ),
            const SizedBox(height: 12),
            MiniBuilder<DemoCheckoutController>(
              controller: _controller,
              id: DemoCheckoutIds.summary,
              builder: (context, controller) {
                return Text('结算结果：${controller.summary}');
              },
            ),
            const SizedBox(height: 4),
            MiniBuilder<DemoCheckoutController>(
              controller: _controller,
              id: DemoCheckoutIds.summary,
              builder: (context, controller) {
                return Text('自动重算次数：${controller.recalculationCount}');
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Mini.batch(() {
                  widget.services.auth.toggleSession();
                  widget.services.cart.addItem();
                });
              },
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('批量切换登录并加入商品'),
            ),
          ],
        ),
      ),
    );
  }
}
