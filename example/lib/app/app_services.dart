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
