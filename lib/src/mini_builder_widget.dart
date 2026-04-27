import 'package:flutter/material.dart';

import 'mini_notifier.dart';

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
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant MiniBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller &&
        oldWidget.id == widget.id) {
      return;
    }

    _unsubscribe(oldWidget.controller, oldWidget.id);
    _subscribe();
  }

  @override
  void dispose() {
    _unsubscribe(widget.controller, widget.id);
    super.dispose();
  }

  void _subscribe() {
    final id = widget.id;
    if (id == null) {
      widget.controller.addListener(_listener);
      return;
    }

    widget.controller.addIdListener(id, _listener);
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
