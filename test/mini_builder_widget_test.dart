import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_builder/mini_builder.dart';

void main() {
  testWidgets('controller is not disposed by MiniBuilder', (tester) async {
    final controller = _TestController();

    await tester.pumpWidget(
      MaterialApp(
        home: MiniBuilder<_TestController>(
          controller: controller,
          builder: (context, controller) {
            return Text('${controller.count}');
          },
        ),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.disposed, isFalse);
    controller.dispose();
  });

  testWidgets('MiniBuilder calls onReady once after first frame', (
    tester,
  ) async {
    final controller = _TestController();

    await tester.pumpWidget(
      MaterialApp(
        home: MiniBuilder<_TestController>(
          controller: controller,
          builder: (context, controller) {
            return Text('${controller.count}');
          },
        ),
      ),
    );

    expect(controller.readyCalled, isTrue);
    expect(controller.readyCount, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: MiniBuilder<_TestController>(
          controller: controller,
          builder: (context, controller) {
            return Text('${controller.count}');
          },
        ),
      ),
    );

    expect(controller.readyCount, 1);

    controller.dispose();
  });

  testWidgets('multiple MiniBuilders call onReady only once', (tester) async {
    final controller = _TestController();

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: <Widget>[
            MiniBuilder<_TestController>(
              controller: controller,
              builder: (context, controller) {
                return Text('first ${controller.count}');
              },
            ),
            MiniBuilder<_TestController>(
              controller: controller,
              builder: (context, controller) {
                return Text('second ${controller.count}');
              },
            ),
          ],
        ),
      ),
    );

    expect(controller.readyCalled, isTrue);
    expect(controller.readyCount, 1);

    controller.dispose();
  });

  testWidgets('switching controller unsubscribes the old one', (tester) async {
    final firstController = _TestController();
    final secondController = _TestController();
    final hostKey = GlobalKey<_MiniBuilderHostState>();

    await tester.pumpWidget(
      MaterialApp(
        home: _MiniBuilderHost(
          key: hostKey,
          controller: firstController,
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);

    hostKey.currentState!.updateController(secondController);
    await tester.pump();

    expect(find.text('0'), findsOneWidget);

    firstController.increase();
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.text('0'), findsOneWidget);

    secondController.increase();
    await tester.pump();

    expect(find.text('1'), findsOneWidget);

    firstController.dispose();
    secondController.dispose();
  });

  testWidgets('switching id unsubscribes the previous id listener', (
    tester,
  ) async {
    final controller = _TestController();
    final hostKey = GlobalKey<_MiniBuilderHostState>();

    await tester.pumpWidget(
      MaterialApp(
        home: _MiniBuilderHost(
          key: hostKey,
          controller: controller,
          id: 'red',
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);

    controller.setValueAndUpdate(1, 'red');
    await tester.pump();

    expect(find.text('1'), findsOneWidget);

    hostKey.currentState!.updateId('blue');
    await tester.pump();

    controller.setValueAndUpdate(2, 'red');
    await tester.pump();

    expect(find.text('2'), findsNothing);
    expect(find.text('1'), findsOneWidget);

    controller.setValueAndUpdate(3, 'blue');
    await tester.pump();

    expect(find.text('3'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('shouldRebuild controls rebuild timing', (tester) async {
    final controller = _TestController();
    var buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MiniBuilder<_TestController>(
          controller: controller,
          shouldRebuild: (controller) => controller.count.isEven,
          builder: (context, controller) {
            buildCount++;
            return Text('${controller.count}');
          },
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    expect(buildCount, 1);

    controller.increase();
    await tester.pump();

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(buildCount, 1);

    controller.increase();
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
    expect(buildCount, 2);

    controller.dispose();
  });

  testWidgets('disposed MiniBuilder does not rebuild after updates', (
    tester,
  ) async {
    final controller = _TestController();
    var buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MiniBuilder<_TestController>(
          controller: controller,
          builder: (context, controller) {
            buildCount++;
            return Text('${controller.count}');
          },
        ),
      ),
    );

    expect(buildCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.increase();
    await tester.pump();

    expect(buildCount, 1);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets('MiniBuilder skips subscription for disposed controller', (
    tester,
  ) async {
    final controller = _TestController()..dispose();

    await tester.pumpWidget(
      MaterialApp(
        home: MiniBuilder<_TestController>(
          controller: controller,
          builder: (context, controller) {
            return Text('${controller.count}');
          },
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MiniBuilder can unmount after controller is disposed', (
    tester,
  ) async {
    final controller = _TestController();

    await tester.pumpWidget(
      MaterialApp(
        home: MiniBuilder<_TestController>(
          controller: controller,
          builder: (context, controller) {
            return Text('${controller.count}');
          },
        ),
      ),
    );

    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });
}

class _TestController extends MiniNotifier {
  int count = 0;
  bool disposed = false;
  int readyCount = 0;

  void increase() {
    count++;
    update();
  }

  void setValueAndUpdate(int nextValue, String id) {
    count = nextValue;
    update([id]);
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  void onReady() {
    super.onReady();
    readyCount++;
  }
}

class _MiniBuilderHost extends StatefulWidget {
  final _TestController controller;
  final String? id;

  const _MiniBuilderHost({
    super.key,
    required this.controller,
    this.id,
  });

  @override
  State<_MiniBuilderHost> createState() => _MiniBuilderHostState();
}

class _MiniBuilderHostState extends State<_MiniBuilderHost> {
  late _TestController _controller;
  String? _id;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _id = widget.id;
  }

  void updateController(_TestController controller) {
    setState(() {
      _controller = controller;
    });
  }

  void updateId(String? id) {
    setState(() {
      _id = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiniBuilder<_TestController>(
      controller: _controller,
      id: _id,
      builder: (context, controller) {
        return Text('${controller.count}');
      },
    );
  }
}
