import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_builder_example/example_log_manager.dart';
import 'package:mini_builder_example/ex/on_init_api_example.dart';

void main() {
  testWidgets('nested controllers request and update from onInit', (
    tester,
  ) async {
    final logs = <String>[];
    ExampleLogManager.instance.configure(enabled: true, sink: logs.add);
    addTearDown(ExampleLogManager.instance.restoreDefaults);

    final pageResponse = Completer<String>();
    final productResponse = Completer<OnInitApiExampleProduct>();
    final api = _ControlledApi(
      pageResponse: pageResponse.future,
      productResponse: productResponse.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OnInitApiExample(api: api)),
      ),
    );

    expect(api.pageRequestCount, 1);
    expect(api.productRequestCount, 1);
    expect(find.text('外层 controller 正在请求 API...'), findsOneWidget);
    expect(find.text('内层 controller 正在请求 API...'), findsOneWidget);
    expect(find.textContaining('实例商品'), findsNothing);

    pageResponse.complete('外层数据刷新完成');
    await tester.pump();

    expect(find.text('外层数据刷新完成'), findsOneWidget);
    expect(find.text('内层 controller 正在请求 API...'), findsOneWidget);

    productResponse.complete(
      const OnInitApiExampleProduct(id: 'sku-test', name: '实例商品'),
    );
    await tester.pump();

    expect(find.text('内层 controller 正在请求 API...'), findsNothing);
    expect(find.text('实例商品 (sku-test)'), findsOneWidget);
    expect(
      logs.any(
        (log) =>
            log.contains('event=api_request_start') &&
            log.contains('source=OnInitApiExampleController'),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (log) =>
            log.contains('event=api_request_succeeded') &&
            log.contains('source=OnInitProductExampleController'),
      ),
      isTrue,
    );
    expect(
      logs.any(
        (log) =>
            log.contains('event=builder_build') && log.contains('scope=inner'),
      ),
      isTrue,
    );
    expect(logs.join('\n'), isNot(contains('实例商品')));
    expect(logs.join('\n'), isNot(contains('sku-test')));
  });

  testWidgets('onInit handles API errors before updating the page', (
    tester,
  ) async {
    final logs = <String>[];
    ExampleLogManager.instance.configure(enabled: true, sink: logs.add);
    addTearDown(ExampleLogManager.instance.restoreDefaults);

    final pageResponse = Completer<String>();
    final productResponse = Completer<OnInitApiExampleProduct>();
    final api = _ControlledApi(
      pageResponse: pageResponse.future,
      productResponse: productResponse.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OnInitApiExample(api: api)),
      ),
    );

    pageResponse.completeError(StateError('page request failed'));
    productResponse.completeError(StateError('product request failed'));
    await tester.pump();

    expect(find.text('外层 API 请求失败'), findsOneWidget);
    expect(find.text('内层 API 请求失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      logs.where((log) => log.contains('event=api_request_failed')).length,
      2,
    );
    expect(logs.every((log) => !log.contains('request failed')), isTrue);
  });
}

class _ControlledApi extends OnInitApiExampleApi {
  final Future<String> pageResponse;
  final Future<OnInitApiExampleProduct> productResponse;
  int pageRequestCount = 0;
  int productRequestCount = 0;

  _ControlledApi({
    required this.pageResponse,
    required this.productResponse,
  }) : super(delay: Duration.zero);

  @override
  Future<String> fetchPageTitle() {
    pageRequestCount++;
    return pageResponse;
  }

  @override
  Future<OnInitApiExampleProduct> fetchProduct() {
    productRequestCount++;
    return productResponse;
  }
}
