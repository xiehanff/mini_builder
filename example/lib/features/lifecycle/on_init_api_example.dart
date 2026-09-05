import 'package:flutter/material.dart';
import 'package:mini_builder/mini_builder.dart';

import '../../shared/example_log_manager.dart';

class OnInitApiExampleProduct {
  final String id;
  final String name;

  const OnInitApiExampleProduct({required this.id, required this.name});
}

class OnInitApiExampleApi {
  final Duration delay;

  const OnInitApiExampleApi({
    this.delay = const Duration(milliseconds: 800),
  });

  Future<String> fetchPageTitle() async {
    await Future<void>.delayed(delay);
    return '外层 controller 的 API 请求已完成';
  }

  Future<OnInitApiExampleProduct> fetchProduct() async {
    await Future<void>.delayed(delay);
    return const OnInitApiExampleProduct(
      id: 'sku-on-init-1001',
      name: 'onInit 请求返回的商品',
    );
  }
}

class OnInitApiExampleController extends MiniNotifier {
  final OnInitApiExampleApi api;

  String? pageTitle;
  String? pageError;

  OnInitApiExampleController({required this.api});

  @override
  void onInit() async {
    super.onInit();
    final logManager = ExampleLogManager.instance;
    final requestId = logManager.nextRequestId();
    final stopwatch = Stopwatch()..start();
    logManager.info(
      'api_request_start',
      source: runtimeType.toString(),
      fields: <String, Object?>{'request_id': requestId},
    );

    late final String nextTitle;
    try {
      nextTitle = await api.fetchPageTitle();
    } catch (error) {
      stopwatch.stop();
      logManager.error(
        'api_request_failed',
        source: runtimeType.toString(),
        fields: <String, Object?>{
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error_type': error.runtimeType,
          'request_id': requestId,
        },
      );
      if (closed) return;

      pageError = '外层 API 请求失败';
      logManager.info(
        'state_update',
        source: runtimeType.toString(),
        fields: <String, Object?>{
          'request_id': requestId,
          'state': 'error',
        },
      );
      update();
      return;
    }
    stopwatch.stop();
    logManager.info(
      'api_request_succeeded',
      source: runtimeType.toString(),
      fields: <String, Object?>{
        'elapsed_ms': stopwatch.elapsedMilliseconds,
        'request_id': requestId,
      },
    );
    if (closed) return;

    pageTitle = nextTitle;
    logManager.info(
      'state_update',
      source: runtimeType.toString(),
      fields: <String, Object?>{
        'request_id': requestId,
        'state': 'success',
      },
    );
    update();
  }
}

class OnInitProductExampleController extends MiniNotifier {
  final OnInitApiExampleApi api;

  OnInitApiExampleProduct? product;
  String? productError;

  OnInitProductExampleController({required this.api});

  @override
  void onInit() async {
    super.onInit();
    final logManager = ExampleLogManager.instance;
    final requestId = logManager.nextRequestId();
    final stopwatch = Stopwatch()..start();
    logManager.info(
      'api_request_start',
      source: runtimeType.toString(),
      fields: <String, Object?>{'request_id': requestId},
    );

    late final OnInitApiExampleProduct nextProduct;
    try {
      nextProduct = await api.fetchProduct();
    } catch (error) {
      stopwatch.stop();
      logManager.error(
        'api_request_failed',
        source: runtimeType.toString(),
        fields: <String, Object?>{
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'error_type': error.runtimeType,
          'request_id': requestId,
        },
      );
      if (closed) return;

      productError = '内层 API 请求失败';
      logManager.info(
        'state_update',
        source: runtimeType.toString(),
        fields: <String, Object?>{
          'request_id': requestId,
          'state': 'error',
        },
      );
      update();
      return;
    }
    stopwatch.stop();
    logManager.info(
      'api_request_succeeded',
      source: runtimeType.toString(),
      fields: <String, Object?>{
        'elapsed_ms': stopwatch.elapsedMilliseconds,
        'request_id': requestId,
      },
    );
    if (closed) return;

    product = nextProduct;
    logManager.info(
      'state_update',
      source: runtimeType.toString(),
      fields: <String, Object?>{
        'request_id': requestId,
        'state': 'success',
      },
    );
    update();
  }
}

class OnInitApiExample extends StatefulWidget {
  final OnInitApiExampleApi api;

  const OnInitApiExample({
    super.key,
    this.api = const OnInitApiExampleApi(),
  });

  @override
  State<OnInitApiExample> createState() => _OnInitApiExampleState();
}

class _OnInitApiExampleState extends State<OnInitApiExample> {
  late final OnInitApiExampleController _pageController;
  late final OnInitProductExampleController _productController;
  int _pageBuildCount = 0;
  int _productBuildCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = OnInitApiExampleController(api: widget.api);
    _productController = OnInitProductExampleController(api: widget.api);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _productController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniBuilder<OnInitApiExampleController>(
      controller: _pageController,
      builder: (context, pageController) {
        _pageBuildCount++;
        ExampleLogManager.instance.info(
          'builder_build',
          source: pageController.runtimeType.toString(),
          fields: <String, Object?>{
            'build_count': _pageBuildCount,
            'scope': 'outer',
          },
        );
        final pageError = pageController.pageError;
        final pageTitle = pageController.pageTitle;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'onInit API 刷新验证',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                    '两个 controller 都在 onInit 内请求 API 并调用 update()，没有使用 onReady。'),
                const SizedBox(height: 16),
                if (pageError != null)
                  Text(
                    pageError,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                else if (pageTitle == null)
                  const Row(
                    children: <Widget>[
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('外层 controller 正在请求 API...'),
                    ],
                  )
                else
                  Text(
                    pageTitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 16),
                // 外层刷新会按 Flutter 的组件树规则更新该子树；
                // 两个 MiniBuilder 的 controller 订阅关系仍然彼此独立。
                MiniBuilder<OnInitProductExampleController>(
                  controller: _productController,
                  builder: (context, productController) {
                    _productBuildCount++;
                    ExampleLogManager.instance.info(
                      'builder_build',
                      source: productController.runtimeType.toString(),
                      fields: <String, Object?>{
                        'build_count': _productBuildCount,
                        'scope': 'inner',
                      },
                    );
                    final productError = productController.productError;
                    final product = productController.product;
                    if (productError != null) {
                      return Text(
                        productError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }

                    if (product == null) {
                      return const Text('内层 controller 正在请求 API...');
                    }

                    return Text(
                      '${product.name} (${product.id})',
                      style: Theme.of(context).textTheme.bodyLarge,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
