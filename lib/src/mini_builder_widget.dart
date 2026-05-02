part of '../mini_builder.dart';

class MiniBuilder<T extends MiniNotifier> extends StatefulWidget {
  final T controller;
  final String? id;
  final bool Function(T controller)? shouldRebuild;
  final Widget Function(BuildContext context, T controller) builder;

  const MiniBuilder({
    super.key,
    required this.controller,
    this.id,
    this.shouldRebuild,
    required this.builder,
  });

  @override
  State<MiniBuilder<T>> createState() => _MiniBuilderState<T>();
}

class _MiniBuilderState<T extends MiniNotifier> extends State<MiniBuilder<T>> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = _handleUpdate;
    widget.controller._ensureInitialized();
    _subscribe();
    _scheduleReady(widget.controller);
  }

  @override
  void didUpdateWidget(covariant MiniBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unsubscribe(oldWidget.controller, oldWidget.id);
      widget.controller._ensureInitialized();
      _subscribe();
      _scheduleReady(widget.controller);
      return;
    }

    if (oldWidget.id == widget.id) return;

    _unsubscribe(widget.controller, oldWidget.id);
    _subscribe();
  }

  @override
  void dispose() {
    _unsubscribe(widget.controller, widget.id);
    super.dispose();
  }

  void _subscribe() {
    if (widget.controller.closed) return;

    final id = widget.id;
    if (id == null) {
      widget.controller.addListener(_listener);
      return;
    }

    widget.controller.addIdListener(id, _listener);
  }

  void _scheduleReady(T controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller != controller) return;

      // onReady 只在 controller 挂到 MiniBuilder 且首帧绘制完成后触发。
      controller._ready();
    });
  }

  void _unsubscribe(MiniNotifier controller, String? id) {
    if (id == null) {
      controller.removeListener(_listener);
      return;
    }

    controller.removeIdListener(id, _listener);
  }

  void _handleUpdate() {
    if (!mounted) return;
    final shouldRebuild = widget.shouldRebuild;
    if (shouldRebuild != null && !shouldRebuild(widget.controller)) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.controller);
  }
}
