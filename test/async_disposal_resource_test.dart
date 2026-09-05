import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_builder/mini_builder.dart';

void main() {
  testWidgets('async update after MiniNotifier disposal is a safe no-op', (
    tester,
  ) async {
    final response = Completer<void>();
    final controller = _LateUpdateController(response.future);
    var notificationCount = 0;

    controller.addListener(() {
      notificationCount++;
    });

    await tester.pump();
    expect(controller.requestStarted, isTrue);

    controller.dispose();
    response.complete();
    await tester.pump();

    expect(controller.closed, isTrue);
    expect(controller.updateAttemptCount, 1);
    expect(notificationCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closed guard prevents access to disposed resources after onReady request',
    (tester) async {
      final response = Completer<String>();
      final controller = _GuardedResourceController(
        response.future,
        vsync: tester,
      );

      await tester.pumpWidget(
        MiniBuilder<_GuardedResourceController>(
          controller: controller,
          builder: (context, controller) {
            return const SizedBox.shrink();
          },
        ),
      );

      expect(controller.requestStarted, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();

      response.complete('late response');
      await tester.pump();

      expect(controller.closed, isTrue);
      expect(controller.callbackResumed, isTrue);
      expect(controller.stateApplied, isFalse);
      expect(controller.resourceAccessCount, 0);
      expect(controller.updateAttemptCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'writing TextEditingController after async response and dispose throws',
    () async {
      final response = Completer<String>();
      final textController = TextEditingController();

      final callback = () async {
        final value = await response.future;
        textController.text = value;
      }();

      textController.dispose();
      response.complete('late response');

      await expectLater(callback, throwsA(_disposedResourceError));
    },
  );

  test(
    'starting AnimationController after async response and dispose throws',
    () async {
      final response = Completer<void>();
      final animationController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 100),
      );

      final callback = () async {
        await response.future;
        animationController.forward();
      }();

      animationController.dispose();
      response.complete();

      await expectLater(callback, throwsA(_disposedResourceError));
    },
  );
}

final Matcher _disposedResourceError = anyOf(
  isA<FlutterError>(),
  isA<AssertionError>(),
);

class _LateUpdateController extends MiniNotifier {
  final Future<void> response;

  bool requestStarted = false;
  int updateAttemptCount = 0;

  _LateUpdateController(this.response);

  @override
  void onInit() {
    super.onInit();
    unawaited(_load());
  }

  Future<void> _load() async {
    requestStarted = true;
    await response;

    // MiniNotifier.update() is intentionally safe after dispose.
    updateAttemptCount++;
    update();
  }
}

class _GuardedResourceController extends MiniNotifier {
  final Future<String> response;
  final TextEditingController textController = TextEditingController();
  late final AnimationController animationController;

  bool requestStarted = false;
  bool callbackResumed = false;
  bool stateApplied = false;
  int resourceAccessCount = 0;
  int updateAttemptCount = 0;

  _GuardedResourceController(
    this.response, {
    required TickerProvider vsync,
  }) {
    animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(_load());
  }

  Future<void> _load() async {
    requestStarted = true;
    final value = await response;
    callbackResumed = true;

    if (closed) return;

    resourceAccessCount++;
    textController.text = value;
    animationController.forward();

    stateApplied = true;
    updateAttemptCount++;
    update();
  }

  @override
  void onClose() {
    textController.dispose();
    animationController.dispose();
    super.onClose();
  }
}
