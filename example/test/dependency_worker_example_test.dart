import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_builder/mini_builder.dart';
import 'package:mini_builder_example/ex/dependency_worker_example.dart';

void main() {
  testWidgets('watchAll recalculates once for a batched global update', (
    tester,
  ) async {
    final services = DemoAppServices();
    addTearDown(services.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniProvider<DemoAppServices>(
            value: services,
            child: const DependencyWorkerExampleEntry(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('结算结果：请先登录'), findsOneWidget);
    expect(find.text('自动重算次数：1'), findsOneWidget);

    await tester.tap(find.text('批量切换登录并加入商品'));
    await tester.pump();

    expect(find.text('结算结果：已登录，购物车 1 件'), findsOneWidget);
    expect(find.text('自动重算次数：2'), findsOneWidget);
  });
}
