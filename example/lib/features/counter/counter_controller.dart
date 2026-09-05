import 'package:mini_builder/mini_builder.dart';

class MiniBuilderExampleIds {
  static const red = 'red';
  static const blue = 'blue';
  static const price = 'price';
  static const recommend = 'recommend';
}

class MiniCounterController extends MiniNotifier {
  int allCount = 0;
  int redCount = 0;
  int blueCount = 0;

  void increaseAll() {
    allCount++;
    redCount++;
    blueCount++;
    update();
  }

  void increaseRed() {
    redCount++;
    update([MiniBuilderExampleIds.red]);
  }

  void increaseBlue() {
    blueCount++;
    update([MiniBuilderExampleIds.blue]);
  }
}
