## 0.1.0

- Initial release.
- `MiniNotifier`: controller base with lifecycle (`onInit`, `onReady`, `onClose`), full rebuild (`update()`), and id-based partial rebuild (`update([id])`).
- `MiniBuilder`: subscribe to a controller and rebuild on demand, supporting optional `id` and `shouldRebuild`.
- `MiniProvider`: inject controller into the widget tree via `InheritedWidget`, with `of<T>()` and `maybeOf<T>()` lookups.
