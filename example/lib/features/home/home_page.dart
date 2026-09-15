import 'package:flutter/material.dart';
import 'package:mini_builder/mini_builder.dart';

import '../counter/counter_controller.dart';
import '../dependency/dependency_worker_example.dart';
import '../lifecycle/on_init_api_example.dart';
import '../product/product_detail_example.dart';

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
      value: _controller,
      child: Scaffold(
        appBar: AppBar(title: const Text('MiniBuilder 示例')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const <Widget>[
              _IntroPanel(),
              SizedBox(height: 16),
              OnInitApiExample(),
              SizedBox(height: 20),
              _AllCounterCard(),
              SizedBox(height: 12),
              _EvenCounterCard(),
              SizedBox(height: 12),
              _IdCounterGrid(),
              SizedBox(height: 20),
              _ActionPanel(),
              SizedBox(height: 28),
              DependencyWorkerExampleEntry(),
              SizedBox(height: 28),
              _SectionTitle(title: '商品详情页场景'),
              SizedBox(height: 12),
              ProductDetailDemo(
                key: ValueKey<String>('product-sku-1001'),
                productId: 'sku-1001',
              ),
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
          valueKey: const ValueKey<String>('all-counter-value'),
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
  final Key? valueKey;
  final String description;
  final Color color;

  const _CounterCard({
    required this.title,
    required this.value,
    this.valueKey,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(71)),
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
              key: valueKey,
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
