part of '../mini_builder.dart';

class MiniProvider<T extends MiniNotifier> extends InheritedWidget {
  final T controller;

  const MiniProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  static T of<T extends MiniNotifier>(BuildContext context) {
    final controller = maybeOf<T>(context);
    if (controller == null) {
      throw FlutterError(
        'MiniProvider.of<$T>() called with a context that does not contain '
        'a MiniProvider<$T>.',
      );
    }

    return controller;
  }

  static T? maybeOf<T extends MiniNotifier>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MiniProvider<T>>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(covariant MiniProvider<T> oldWidget) {
    return oldWidget.controller != controller;
  }
}
