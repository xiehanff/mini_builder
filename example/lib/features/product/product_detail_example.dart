import 'package:flutter/material.dart';
import 'package:mini_builder/mini_builder.dart';

abstract final class ProductDetailIds {
  static const price = 'product.price';
  static const recommend = 'product.recommend';
}

class ProductDetailController extends MiniNotifier {
  final String productId;
  int viewCount = 0;
  int priceRefreshCount = 0;
  int recommendRefreshCount = 0;

  ProductDetailController(this.productId);

  @override
  void onInit() {
    super.onInit();
    loadProduct();
  }

  void loadProduct() {
    viewCount++;
    update();
  }

  void refreshPrice() {
    priceRefreshCount++;
    update([ProductDetailIds.price]);
  }

  void refreshRecommend() {
    recommendRefreshCount++;
    update([ProductDetailIds.recommend]);
  }
}

class ProductDetailDemo extends StatefulWidget {
  final String productId;

  const ProductDetailDemo({super.key, required this.productId});

  @override
  State<ProductDetailDemo> createState() => _ProductDetailDemoState();
}

class _ProductDetailDemoState extends State<ProductDetailDemo> {
  late ProductDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProductDetailController(widget.productId);
  }

  @override
  void didUpdateWidget(covariant ProductDetailDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId == widget.productId) return;

    _controller.dispose();
    _controller = ProductDetailController(widget.productId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniProvider<ProductDetailController>(
      value: _controller,
      child: const _ProductDetailContent(),
    );
  }
}

class _ProductDetailContent extends StatelessWidget {
  const _ProductDetailContent();

  @override
  Widget build(BuildContext context) {
    final controller = MiniProvider.of<ProductDetailController>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MiniBuilder<ProductDetailController>(
          controller: controller,
          builder: (context, controller) {
            return _ProductCard(
              title: '商品 ${controller.productId}',
              description: '全量 update 会刷新浏览次数，也会通知所有 id 区域。',
              child: Text(
                '浏览次数: ${controller.viewCount}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        MiniBuilder<ProductDetailController>(
          controller: controller,
          id: ProductDetailIds.price,
          builder: (context, controller) {
            return _ProductCard(
              title: '价格区域',
              description: "绑定 id: '${ProductDetailIds.price}'",
              child: Text('价格刷新次数: ${controller.priceRefreshCount}'),
            );
          },
        ),
        const SizedBox(height: 12),
        MiniBuilder<ProductDetailController>(
          controller: controller,
          id: ProductDetailIds.recommend,
          shouldRebuild: (controller) =>
              controller.recommendRefreshCount.isEven,
          builder: (context, controller) {
            return _ProductCard(
              title: '相似商品推荐',
              description: '推荐区收到 id 通知后，只在偶数次刷新时重建。',
              child: Text('推荐刷新次数: ${controller.recommendRefreshCount}'),
            );
          },
        ),
        const SizedBox(height: 12),
        _ProductActionPanel(controller: controller),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _ProductCard({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(description, style: textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProductActionPanel extends StatelessWidget {
  final ProductDetailController controller;

  const _ProductActionPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        FilledButton.icon(
          onPressed: controller.loadProduct,
          icon: const Icon(Icons.refresh),
          label: const Text('商品全量刷新'),
        ),
        OutlinedButton.icon(
          onPressed: controller.refreshPrice,
          icon: const Icon(Icons.sell),
          label: const Text('刷新价格 id'),
        ),
        OutlinedButton.icon(
          onPressed: controller.refreshRecommend,
          icon: const Icon(Icons.recommend),
          label: const Text('刷新推荐 id'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) {
                  return _ProductDetailRoutePage(
                    productId: '${controller.productId}-similar',
                  );
                },
              ),
            );
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('打开相似商品'),
        ),
      ],
    );
  }
}

class _ProductDetailRoutePage extends StatelessWidget {
  final String productId;

  const _ProductDetailRoutePage({required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('商品 $productId')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            ProductDetailDemo(
              key: ValueKey<String>('product-$productId'),
              productId: productId,
            ),
          ],
        ),
      ),
    );
  }
}
