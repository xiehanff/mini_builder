import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_builder/mini_builder.dart';

void main() {
  test('constructor schedules onInit once', () async {
    final controller = _LifecycleController();

    expect(controller.initialized, isFalse);

    await pumpEventQueue();

    expect(controller.initialized, isTrue);
    expect(controller.onInitCount, 1);

    controller.dispose();
  });

  test('onInit runs after constructor body', () async {
    final controller = _ConstructorBodyController('sku-1001');

    await pumpEventQueue();

    expect(controller.initialized, isTrue);
    expect(controller.initProductId, 'sku-1001');

    controller.dispose();
  });

  test('dispose calls onClose once and clears id listeners', () {
    final controller = _LifecycleController();
    var idNotifyCount = 0;

    controller.addIdListener('red', () {
      idNotifyCount++;
    });

    controller.dispose();
    controller.dispose();

    expect(controller.closed, isTrue);
    expect(controller.onCloseCount, 1);
    expect(idNotifyCount, 0);
  });

  test('dispose completes framework cleanup when onClose throws', () {
    final controller = _ThrowingCloseController();
    var idNotifyCount = 0;

    controller.addIdListener('red', () {
      idNotifyCount++;
    });

    expect(controller.dispose, throwsStateError);
    expect(controller.closed, isTrue);

    // A second dispose is idempotent even though the first onClose failed.
    expect(controller.dispose, returnsNormally);
    controller.update(['red']);
    expect(idNotifyCount, 0);

    // ChangeNotifier.dispose() must have run from finally.
    expect(
      () => controller.addListener(() {}),
      throwsA(anyOf(isA<FlutterError>(), isA<AssertionError>())),
    );
  });

  test('lifecycle hooks print debug logs once', () async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) return;

      logs.add(message);
    };

    try {
      final controller = _LifecycleController();

      await pumpEventQueue();

      controller.dispose();
      controller.dispose();

      expect(logs, <String>[
        '[mini_builder] _LifecycleController.onInit',
        '[mini_builder] _LifecycleController.onClose',
      ]);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  test('update after dispose is a no-op', () {
    final controller = _LifecycleController();
    var globalNotifyCount = 0;
    var idNotifyCount = 0;

    controller.addListener(() {
      globalNotifyCount++;
    });
    controller.addIdListener('red', () {
      idNotifyCount++;
    });

    controller.dispose();
    controller.update();
    controller.update(['red']);

    expect(globalNotifyCount, 0);
    expect(idNotifyCount, 0);
  });

  test('addIdListener after dispose is a no-op', () {
    final controller = _LifecycleController();
    var idNotifyCount = 0;

    controller.dispose();
    controller.addIdListener('red', () {
      idNotifyCount++;
    });
    controller.update(['red']);

    expect(idNotifyCount, 0);
  });

  test('update notifies global and id listeners', () {
    final controller = _LifecycleController();
    var globalNotifyCount = 0;
    var redNotifyCount = 0;
    var blueNotifyCount = 0;

    controller.addListener(() {
      globalNotifyCount++;
    });
    controller.addIdListener('red', () {
      redNotifyCount++;
    });
    controller.addIdListener('blue', () {
      blueNotifyCount++;
    });

    controller.update();

    expect(globalNotifyCount, 1);
    expect(redNotifyCount, 1);
    expect(blueNotifyCount, 1);

    controller.dispose();
  });

  test('update with empty ids triggers assert in debug mode', () {
    final controller = _LifecycleController();
    var globalNotifyCount = 0;
    var redNotifyCount = 0;

    controller.addListener(() {
      globalNotifyCount++;
    });
    controller.addIdListener('red', () {
      redNotifyCount++;
    });

    // 在 debug 模式下应该触发断言
    expect(
      () => controller.update([]),
      throwsAssertionError,
    );

    expect(globalNotifyCount, 0);
    expect(redNotifyCount, 0);

    controller.dispose();
  });

  test('update with duplicate ids notifies each id once', () {
    final controller = _LifecycleController();
    var redNotifyCount = 0;

    controller.addIdListener('red', () {
      redNotifyCount++;
    });

    controller.update(['red', 'red', 'red']);

    expect(redNotifyCount, 1);
    controller.dispose();
  });

  test('update with id only notifies matching id listeners', () {
    final controller = _LifecycleController();
    var globalNotifyCount = 0;
    var redNotifyCount = 0;
    var blueNotifyCount = 0;

    controller.addListener(() {
      globalNotifyCount++;
    });
    controller.addIdListener('red', () {
      redNotifyCount++;
    });
    controller.addIdListener('blue', () {
      blueNotifyCount++;
    });

    controller.update(['red']);

    expect(globalNotifyCount, 0);
    expect(redNotifyCount, 1);
    expect(blueNotifyCount, 0);

    controller.dispose();
  });

  test('id listener failure does not prevent later listeners', () {
    final controller = _LifecycleController();
    var secondNotifyCount = 0;
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;

    try {
      controller.addIdListener('red', () {
        throw StateError('listener failed');
      });
      controller.addIdListener('red', () {
        secondNotifyCount++;
      });

      expect(() => controller.update(['red']), returnsNormally);
      expect(secondNotifyCount, 1);
      expect(reportedErrors, hasLength(1));
      expect(reportedErrors.single.exception, isA<StateError>());
    } finally {
      FlutterError.onError = previousOnError;
      controller.dispose();
    }
  });

  test('update with nonexistent id is a no-op', () {
    final controller = _LifecycleController();
    var redNotifyCount = 0;

    controller.addIdListener('red', () {
      redNotifyCount++;
    });

    controller.update(['blue']);

    expect(redNotifyCount, 0);

    controller.dispose();
  });

  test('same id listener can be registered and removed independently', () {
    final controller = _LifecycleController();
    var notifyCount = 0;

    void listener() {
      notifyCount++;
    }

    controller.addIdListener('red', listener);
    controller.addIdListener('red', listener);

    controller.update(['red']);
    expect(notifyCount, 2);

    controller.removeIdListener('red', listener);
    controller.update(['red']);
    expect(notifyCount, 3);

    controller.dispose();
  });

  test('listener can remove itself during id update', () {
    final controller = _LifecycleController();
    var firstNotifyCount = 0;
    var secondNotifyCount = 0;

    late final void Function() firstListener;
    firstListener = () {
      firstNotifyCount++;
      controller.removeIdListener('red', firstListener);
    };

    controller.addIdListener('red', firstListener);
    controller.addIdListener('red', () {
      secondNotifyCount++;
    });

    controller.update(['red']);

    expect(firstNotifyCount, 1);
    expect(secondNotifyCount, 1);

    controller.dispose();
  });

  test('ids use centralized string constants without collisions', () {
    final controller = _LifecycleController();
    var notifyCount = 0;

    controller.addIdListener(_RefreshId.red, () {
      notifyCount++;
    });

    controller.update([_RefreshId.red]);

    expect(notifyCount, 1);
    controller.dispose();
  });

  test('update keeps the original string-list override signature', () {
    final controller = _StringOverrideController();

    controller.update(<String>[_RefreshId.red]);

    expect(controller.lastIds, <String>[_RefreshId.red]);
    controller.dispose();
  });

  test('watch filters source changes and is disposed with its owner', () {
    final source = _LifecycleController();
    final owner = _LifecycleController();
    final received = <MiniChange>[];

    owner.watch(
      source,
      ids: const <String>[_RefreshId.red],
      onChanged: received.add,
    );

    source.update([_RefreshId.blue]);
    source.update([_RefreshId.red]);
    source.update();

    expect(received, hasLength(2));
    expect(received.first.ids, <String>{_RefreshId.red});
    expect(received.last.isFullRefresh, isTrue);

    owner.dispose();
    source.update([_RefreshId.red]);
    expect(received, hasLength(2));

    source.dispose();
  });

  test('watching from a disposed owner returns a cancelled worker', () {
    final source = _LifecycleController();
    final owner = _LifecycleController()..dispose();
    var notifyCount = 0;

    final worker = owner.watch(source, onChanged: (_) {
      notifyCount++;
    });
    source.update();

    expect(worker.disposed, isTrue);
    expect(notifyCount, 0);
    source.dispose();
  });

  test('watch rejects circular controller dependencies', () {
    final first = _LifecycleController();
    final second = _LifecycleController();

    first.watch(second, onChanged: (_) {});

    expect(
      () => second.watch(first, onChanged: (_) {}),
      throwsA(isA<FlutterError>()),
    );

    first.dispose();
    second.dispose();
  });

  test('watchAll coalesces synchronous dependency changes', () async {
    final cart = _LifecycleController();
    final auth = _LifecycleController();
    final owner = _LifecycleController();
    final changes = <List<MiniChange>>[];

    owner.watchAll(
      <MiniWatchSource>[
        MiniWatchSource(cart, ids: <String>[_RefreshId.red]),
        MiniWatchSource(auth, ids: <String>[_RefreshId.blue]),
      ],
      onChanged: changes.add,
    );

    cart.update([_RefreshId.red]);
    auth.update([_RefreshId.blue]);
    await pumpEventQueue();

    expect(changes, hasLength(1));
    expect(changes.single, hasLength(2));

    owner.dispose();
    cart.dispose();
    auth.dispose();
  });

  test('Mini.batch merges changes from the same controller', () {
    final controller = _LifecycleController();
    final changes = <MiniChange>[];
    controller.addChangeListener(changes.add);

    Mini.batch(() {
      controller.update([_RefreshId.red]);
      controller.update([_RefreshId.blue]);
    });

    expect(changes, hasLength(1));
    expect(changes.single.ids, <String>{_RefreshId.red, _RefreshId.blue});
    controller.dispose();
  });

  testWidgets('disposing an owner cancels its debounce timer', (tester) async {
    final source = _LifecycleController();
    final owner = _LifecycleController();
    var notifyCount = 0;

    owner.debounce(
      source,
      duration: const Duration(seconds: 1),
      onChanged: (_) {
        notifyCount++;
      },
    );

    source.update();
    owner.dispose();
    await tester.pump(const Duration(seconds: 1));

    expect(notifyCount, 0);
    source.dispose();
  });

  testWidgets('interval resumes after its callback throws', (tester) async {
    final source = _LifecycleController();
    final owner = _LifecycleController();
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    var notifyCount = 0;
    FlutterError.onError = reportedErrors.add;

    try {
      owner.interval(
        source,
        duration: const Duration(seconds: 1),
        onChanged: (_) {
          notifyCount++;
          throw StateError('interval callback failed');
        },
      );

      source.update();
      await tester.pump(const Duration(seconds: 1));
      source.update();

      expect(notifyCount, 2);
      expect(reportedErrors, hasLength(2));
    } finally {
      FlutterError.onError = previousOnError;
      owner.dispose();
      source.dispose();
    }
  });

  testWidgets('watchAll reports coalesced callback errors', (tester) async {
    final source = _LifecycleController();
    final owner = _LifecycleController();
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;

    try {
      owner.watchAll(
        <MiniWatchSource>[MiniWatchSource(source)],
        onChanged: (_) {
          throw StateError('coalesced callback failed');
        },
      );

      source.update();
      await tester.pump();

      expect(reportedErrors, hasLength(1));
      expect(reportedErrors.single.exception, isA<StateError>());
    } finally {
      FlutterError.onError = previousOnError;
      owner.dispose();
      source.dispose();
    }
  });
}

abstract final class _RefreshId {
  static const red = 'red';
  static const blue = 'blue';
}

class _LifecycleController extends MiniNotifier {
  int onInitCount = 0;
  int onReadyCount = 0;
  int onCloseCount = 0;

  @override
  void onInit() {
    super.onInit();
    onInitCount++;
  }

  @override
  void onReady() {
    super.onReady();
    onReadyCount++;
  }

  @override
  void onClose() {
    super.onClose();
    onCloseCount++;
  }
}

class _ThrowingCloseController extends MiniNotifier {
  @override
  void onClose() {
    super.onClose();
    throw StateError('close failed');
  }
}

class _ConstructorBodyController extends MiniNotifier {
  late final String productId;
  String? initProductId;

  _ConstructorBodyController(String nextProductId) {
    productId = nextProductId;
  }

  @override
  void onInit() {
    super.onInit();
    initProductId = productId;
  }
}

class _StringOverrideController extends MiniNotifier {
  List<String>? lastIds;

  @override
  void update([List<String>? ids]) {
    lastIds = ids;
    super.update(ids);
  }
}
