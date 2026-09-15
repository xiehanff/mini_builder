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
          value: controller,
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
          value: outer,
          child: MiniProvider<_TestController>(
            value: inner,
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

  testWidgets('MiniProvider provides application dependencies', (
    tester,
  ) async {
    const services = _AppServices('signed-in-user');

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MiniProvider<_AppServices>(
          value: services,
          child: Builder(
            builder: _appServicesText,
          ),
        ),
      ),
    );

    expect(find.text('signed-in-user'), findsOneWidget);
  });

  testWidgets('MiniProvider notifies dependents only when value changes', (
    tester,
  ) async {
    final hostKey = GlobalKey<_ScopeHostState>();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _ScopeHost(key: hostKey),
      ),
    );

    expect(find.text('first: 1'), findsOneWidget);

    hostKey.currentState!.rebuildWithSameValue();
    await tester.pump();
    expect(find.text('first: 1'), findsOneWidget);

    hostKey.currentState!.replaceValue();
    await tester.pump();
    expect(find.text('second: 2'), findsOneWidget);
  });
}

Widget _appServicesText(BuildContext context) {
  return Text(MiniProvider.of<_AppServices>(context).userName);
}

class _AppServices {
  const _AppServices(this.userName);

  final String userName;
}

class _ScopeHost extends StatefulWidget {
  const _ScopeHost({super.key});

  @override
  State<_ScopeHost> createState() => _ScopeHostState();
}

class _ScopeHostState extends State<_ScopeHost> {
  _AppServices services = const _AppServices('first');

  void rebuildWithSameValue() {
    setState(() {});
  }

  void replaceValue() {
    setState(() {
      services = const _AppServices('second');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiniProvider<_AppServices>(
      value: services,
      child: const _ScopeConsumer(),
    );
  }
}

class _ScopeConsumer extends StatefulWidget {
  const _ScopeConsumer();

  @override
  State<_ScopeConsumer> createState() => _ScopeConsumerState();
}

class _ScopeConsumerState extends State<_ScopeConsumer> {
  var dependencyChanges = 0;
  late String userName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dependencyChanges++;
    userName = MiniProvider.of<_AppServices>(context).userName;
  }

  @override
  Widget build(BuildContext context) {
    return Text('$userName: $dependencyChanges');
  }
}

class _TestController extends MiniNotifier {
  int count = 0;
}
