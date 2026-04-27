import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_builder/mini_builder.dart';

void main() {
  testWidgets('of reads controller from nearest MiniProvider', (tester) async {
    final controller = _TestController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MiniProvider<_TestController>(
          controller: controller,
          child: Builder(
            builder: (context) {
              return Text('${MiniProvider.of<_TestController>(context).count}');
            },
          ),
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('maybeOf returns null when MiniProvider is missing', (
    tester,
  ) async {
    _TestController? controller;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          controller = MiniProvider.maybeOf<_TestController>(context);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(controller, isNull);
  });

  testWidgets('nested providers of the same type return the nearest one', (
    tester,
  ) async {
    final outer = _TestController()..count = 1;
    final inner = _TestController()..count = 2;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MiniProvider<_TestController>(
          controller: outer,
          child: MiniProvider<_TestController>(
            controller: inner,
            child: Builder(
              builder: (context) {
                final controller = MiniProvider.of<_TestController>(context);
                return Text('${controller.count}');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('2'), findsOneWidget);

    outer.dispose();
    inner.dispose();
  });
}

class _TestController extends MiniNotifier {
  int count = 0;
}
