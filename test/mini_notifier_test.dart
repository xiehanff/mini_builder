import 'package:flutter_test/flutter_test.dart';
import 'package:mini_builder/mini_builder.dart';

void main() {
  test('init calls onInit once', () {
    final controller = _LifecycleController();

    controller.init();
    controller.init();

    expect(controller.initialized, isTrue);
    expect(controller.onInitCount, 1);

    controller.dispose();
  });

  test('ready calls onReady once', () {
    final controller = _LifecycleController();

    controller.ready();
    controller.ready();

    expect(controller.readyCalled, isTrue);
    expect(controller.onReadyCount, 1);

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
