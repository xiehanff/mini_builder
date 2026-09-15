import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_builder/mini_builder.dart';
import 'package:mini_builder_example/features/counter/counter_controller.dart';

void main() {
  testWidgets('MiniBuilder refreshes the example counter', (
    WidgetTester tester,
  ) async {
    final controller = MiniCounterController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MiniProvider<MiniCounterController>(
          value: controller,
          child: MiniBuilder<MiniCounterController>(
            controller: controller,
            builder: (context, controller) {
              return Text(
                '${controller.allCount}',
                key: const ValueKey<String>('all-counter-value'),
              );
            },
          ),
        ),
      ),
    );

    final allCounter = find.byKey(const ValueKey<String>('all-counter-value'));
    expect(tester.widget<Text>(allCounter).data, '0');

    controller.increaseAll();
    await tester.pump();

    expect(tester.widget<Text>(allCounter).data, '1');
  });
}
