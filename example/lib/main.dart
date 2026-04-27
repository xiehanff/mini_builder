import 'package:flutter/material.dart';
import 'package:mini_builder/mini_builder.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniBuilder Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MiniBuilderExamplePage(),
    );
  }
}

class MiniBuilderExampleIds {
  static const red = 'red';
  static const blue = 'blue';
  static const price = 'price';
  static const recommend = 'recommend';
}

class MiniCounterController extends MiniNotifier {
  int allCount = 0;
  int redCount = 0;
  int blueCount = 0;

  void increaseAll() {
    allCount++;
    redCount++;
    blueCount++;
    update();
  }

  void increaseRed() {
    redCount++;
    update([MiniBuilderExampleIds.red]);
  }

  void increaseBlue() {
    blueCount++;
    update([MiniBuilderExampleIds.blue]);
  }
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
    update([MiniBuilderExampleIds.price]);
  }

  void refreshRecommend() {
    recommendRefreshCount++;
    update([MiniBuilderExampleIds.recommend]);
  }
}

class MiniBuilderExamplePage extends StatefulWidget {
  const MiniBuilderExamplePage({super.key});

  @override
  State<MiniBuilderExamplePage> createState() => _MiniBuilderExamplePageState();
}

class _MiniBuilderExamplePageState extends State<MiniBuilderExamplePage> {
  final MiniCounterController _controller = MiniCounterController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniProvider<MiniCounterController>(
      controller: _controller,
      child: Scaffold(
        appBar: AppBar(title: const Text('MiniBuilder 示例')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const <Widget>[
              _IntroPanel(),
              SizedBox(height: 16),
              _AllCounterCard(),
              SizedBox(height: 12),
              _EvenCounterCard(),
              SizedBox(height: 12),
              _IdCounterGrid(),
              SizedBox(height: 20),
              _ActionPanel(),
              SizedBox(height: 28),
              _SectionTitle(title: '商品详情页场景'),
              SizedBox(height: 12),
              ProductDetailDemo(productId: 'sku-1001'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('GetBuilder 风格的细粒度刷新', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '全量更新会刷新普通 MiniBuilder；指定 id 更新时，只刷新绑定相同 id 的区域；shouldRebuild 可按业务条件跳过重建。',
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _AllCounterCard extends StatelessWidget {
  const _AllCounterCard();

  @override
  Widget build(BuildContext context) {
    final controller = MiniProvider.of<MiniCounterController>(context);

    return MiniBuilder<MiniCounterController>(
      controller: controller,
      builder: (context, controller) {
        return _CounterCard(
          title: '全量区域',
          value: controller.allCount,
          description: '只会被 update() 刷新',
          color: Theme.of(context).colorScheme.primary,
        );
      },
    );
  }
}

class _EvenCounterCard extends StatelessWidget {
  const _EvenCounterCard();

  @override
  Widget build(BuildContext context) {
    final controller = MiniProvider.of<MiniCounterController>(context);

    return MiniBuilder<MiniCounterController>(
      controller: controller,
      shouldRebuild: (controller) => controller.allCount.isEven,
      builder: (context, controller) {
        return _CounterCard(
          title: 'shouldRebuild 区域',
          value: controller.allCount,
          description: '只在全量计数为偶数时重建',
          color: Theme.of(context).colorScheme.tertiary,
        );
      },
    );
  }
}

class _IdCounterGrid extends StatelessWidget {
  const _IdCounterGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final cards = <Widget>[
          const _RedCounterCard(),
          const _BlueCounterCard(),
        ];

        if (!isWide) {
          return Column(
            children: <Widget>[
              cards.first,
              const SizedBox(height: 12),
              cards.last,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: cards.first),
            const SizedBox(width: 12),
            Expanded(child: cards.last),
          ],
        );
      },
    );
  }
}

class _RedCounterCard extends StatelessWidget {
  const _RedCounterCard();

  @override
  Widget build(BuildContext context) {
    final controller = MiniProvider.of<MiniCounterController>(context);

    return MiniBuilder<MiniCounterController>(
      controller: controller,
      id: MiniBuilderExampleIds.red,
      builder: (context, controller) {
        return _CounterCard(
          title: '红色 id 区域',
          value: controller.redCount,
          description: "绑定 id: '${MiniBuilderExampleIds.red}'",
          color: Colors.red.shade600,
        );
      },
    );
  }
}

class _BlueCounterCard extends StatelessWidget {
  const _BlueCounterCard();

  @override
  Widget build(BuildContext context) {
    final controller = MiniProvider.of<MiniCounterController>(context);

    return MiniBuilder<MiniCounterController>(
      controller: controller,
      id: MiniBuilderExampleIds.blue,
      builder: (context, controller) {
        return _CounterCard(
          title: '蓝色 id 区域',
          value: controller.blueCount,
          description: "绑定 id: '${MiniBuilderExampleIds.blue}'",
          color: Colors.blue.shade600,
        );
      },
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String title;
  final int value;
  final String description;
  final Color color;

  const _CounterCard({
    required this.title,
    required this.value,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.28)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: textTheme.displaySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(description, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel();

  @override
  Widget build(BuildContext context) {
    final controller = MiniProvider.of<MiniCounterController>(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        FilledButton.icon(
          onPressed: controller.increaseAll,
          icon: const Icon(Icons.refresh),
          label: const Text('全量 update'),
        ),
        OutlinedButton.icon(
          onPressed: controller.increaseRed,
          icon: const Icon(Icons.circle, color: Colors.red),
          label: const Text('只更新红色 id'),
        ),
        OutlinedButton.icon(
          onPressed: controller.increaseBlue,
          icon: const Icon(Icons.circle, color: Colors.blue),
          label: const Text('只更新蓝色 id'),
        ),
      ],
    );
  }
}

class ProductDetailDemo extends StatefulWidget {
  final String productId;

  const ProductDetailDemo({super.key, required this.productId});

  @override
  State<ProductDetailDemo> createState() => _ProductDetailDemoState();
}

class _ProductDetailDemoState extends State<ProductDetailDemo> {
  late final ProductDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProductDetailController(widget.productId)..init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.ready();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniProvider<ProductDetailController>(
      controller: _controller,
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
          id: MiniBuilderExampleIds.price,
          builder: (context, controller) {
            return _ProductCard(
              title: '价格区域',
              description: "绑定 id: '${MiniBuilderExampleIds.price}'",
              child: Text('价格刷新次数: ${controller.priceRefreshCount}'),
            );
          },
        ),
        const SizedBox(height: 12),
        MiniBuilder<ProductDetailController>(
          controller: controller,
          id: MiniBuilderExampleIds.recommend,
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
            ProductDetailDemo(productId: productId),
          ],
        ),
      ),
    );
  }
}
