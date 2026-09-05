part of '../mini_builder.dart';

/// 向 widget 子树提供显式创建的值。
///
/// 使用 [MiniProvider] 注入 controller 或应用依赖。
class MiniProvider<T> extends InheritedWidget {
  /// 通过 [InheritedWidget] 向子孙 widget 提供 [value]。
  ///
  /// 此 widget 仅在父 widget 重建且 [value] 变化时（由 [updateShouldNotify] 判断）
  /// 才通知依赖者。
  ///
  /// **重要**：此 widget 不会自动追踪 [value] 内部的变化，
  /// 仅在 [value] 本身变化（引用或相等性）时响应。
  ///
  /// 典型用法：
  /// ```dart
  /// // ✅ 注入稳定的 controller 引用（late final）
  /// class _AppState extends State<App> {
  ///   late final services = AppServices(
  ///     auth: AuthController(),
  ///     cart: CartController(),
  ///   );
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return MiniProvider<AppServices>(
  ///       value: services,  // 引用永不改变
  ///       child: MaterialApp(...),
  ///     );
  ///   }
  /// }
  /// ```
  ///
  /// Controller 在内部状态变化时通过自己的 `update()` 通知监听器。
  /// 此 widget 仅负责依赖注入。
  ///
  /// 对于未重写 `operator ==` 的 [value] 类型，应确保引用保持稳定
  /// （如使用 `late final`），以避免不必要的依赖者重建。
  const MiniProvider({
    super.key,
    required this.value,
    required super.child,
  });

  final T value;

  static T of<T>(BuildContext context) {
    final value = maybeOf<T>(context);
    if (value == null) {
      throw FlutterError(
        'MiniProvider.of<$T>() called with a context that does not contain '
        'a MiniProvider<$T>.',
      );
    }

    return value;
  }

  static T? maybeOf<T>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MiniProvider<T>>()?.value;
  }

  @override
  bool updateShouldNotify(covariant MiniProvider<T> oldWidget) {
    return oldWidget.value != value;
  }
}
