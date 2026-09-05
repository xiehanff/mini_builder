import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_builder_example/features/product/product_detail_example.dart';

void main() {
  testWidgets('product detail replaces its controller when productId changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProductDetailDemo(productId: 'sku-first'),
      ),
    );
    await tester.pump();

    expect(find.text('商品 sku-first'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProductDetailDemo(productId: 'sku-second'),
      ),
    );
    await tester.pump();

    expect(find.text('商品 sku-first'), findsNothing);
    expect(find.text('商品 sku-second'), findsOneWidget);
  });
}
